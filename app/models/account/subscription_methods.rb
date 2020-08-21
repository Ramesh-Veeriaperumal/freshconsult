class Account < ActiveRecord::Base
  include MixpanelWrapper
  include Redis::RedisKeys
  include Redis::OthersRedis
  include SubscriptionHelper
  WIN_BACK_PERIOD = 2.freeze
  SECONDS_IN_A_DAY = 24 * 60 * 60
  SECONDS_IN_TEN_DAYS = 10 * SECONDS_IN_A_DAY

  def customer_details
    {
      :full_domain => "#{self.name}(#{self.full_domain})",
      :account_id => self.id,
      :admin_name => self.admin_first_name,
      :admin_email => self.admin_email,
      :status => FreshdeskCore::Model::STATUS[:scheduled],
      :account_info => account_info
    }
  end

  def account_info
    Sharding.run_on_slave do
      {
        :plan => self.subscription.subscription_plan_id,
        :agents_count => self.agents.count,
        :tickets_count => self.tickets.count,
        :user_count => self.contacts.count,
        :account_created_on => self.created_at
      }
    end
  end

  def update_crm
    CRMApp::Freshsales::DeletedCustomer.perform_async(account_id: self.id, admin_email: self.admin_email) if Rails.env.production?
  end

  def create_deleted_customers_info
    DeletedCustomers.create(customer_details) if self.subscription.active?
  end

  def add_churn
      Subscriptions::AddDeletedEvent.perform_async({ :account_id => self.id })
  end

  def schedule_cleanup
    self.subscription.update_attributes(:state => "suspended")
    jid = AccountCleanup::DeleteAccount.perform_in(14.days.from_now, {:account_id => self.id})
    dc = DeletedCustomers.find_by_account_id(self.id)
    dc.update_attributes({:job_id => jid}) if dc
  end

  def clear_account_data
    self.subscription.update_attributes(:state => "suspended")
    AccountCleanup::DeleteAccount.perform_async({:account_id => self.id})
    ::MixpanelWrapper.send_to_mixpanel("AccountsController")
  end

  def renewal_extend
    subscription = self.subscription
    data = {:term_ends_at => WIN_BACK_PERIOD.days.from_now.utc.to_i.to_s}
    result = Billing::ChargebeeWrapper.new.change_term_end(subscription.account_id, data)
    subscription.next_renewal_at = WIN_BACK_PERIOD.days.from_now.utc
    subscription.save!
  end

  # Any new changes made to this method please validate if it needs to be added to
  # perform_anonymous_account_cancellation method too
  def perform_account_cancellation(feedback = {})
    response = subscription.billing.cancel_subscription(self)
    if response
      cancellation_feedback = "#{feedback[:title]} #{feedback[:additional_info]}"
      send_account_deleted_email(cancellation_feedback)
      update_crm
      create_deleted_customers_info
      send_account_cancelled_email
      clear_account_data
    else
      Rails.logger.info 'Account cancellation failed.'
    end
  end

  def perform_anonymous_account_cancellation
    create_deleted_customers_info
    clear_account_data
  end

  def schedule_account_cancellation_request(feedback, current_user)
    SubscriptionNotifier.send_later(:deliver_account_cancellation_requested, feedback, current_user) if Rails.env.production?
    unless account_cancellation_requested?
      if launched?(:downgrade_policy)
        result = Billing::Subscription.new.cancel_subscription(self, end_of_term: true)
        end_date_time = DateTime.parse(Time.at(result.subscription.current_term_end + 12.hours).to_s)
        expiry_time = ((end_date_time - DateTime.now) * SECONDS_IN_A_DAY).to_i
        set_others_redis_key(account_cancellation_request_time_key, DateTime.now.strftime('%Q'), expiry_time)
        trigger_downgrade_policy_reminder_scheduler
        subscription_request.destroy if subscription_request.present?
      else
        job_id = AccountCancelWorker.perform_in(WIN_BACK_PERIOD.days.from_now, account_id: id)
        set_others_redis_key(account_cancellation_request_job_key, job_id, SECONDS_IN_TEN_DAYS)
        renewal_extend if subscription.renewal_in_two_days?
      end
    end
  end

  def send_account_cancelled_email
    SubscriptionNotifier.send_email_to_group(:admin_account_cancelled, self.account_managers.map(&:email)) if Rails.env.production?
  end

  def perform_cancellation_for_paid_account
    response = subscription.billing.cancel_subscription(self)
    if response
      perform_paid_account_cancellation_actions
      delete_account_cancellation_request_job_key
    else
      Rails.logger.info 'Account cancellation failed.'
    end
  end

  def send_account_deleted_email(feedback)
    SubscriptionNotifier.account_deleted(self,feedback) if Rails.env.production?
  end

  def paid_account?
    self.subscription.active? or self.subscription_payments.present?
  end

  def destroy_all_slack_rule
    account_va_rules.slack_destroy.destroy_all
  end

  def perform_paid_account_cancellation_actions
    update_crm
    create_deleted_customers_info
    add_churn
    send_account_cancelled_email
    schedule_cleanup
  end

  def deletion_scheduled?
    DeletedCustomers.find_by_account_id(self.id).present?
  end

  def fetch_all_admins_email
    to_email = []
    technicians.each do |agent|
      to_email << agent.email if agent.privilege?(:admin_tasks)
    end
    to_email
  end

  def fetch_all_account_admin_email
    to_email = []
    technicians.each do |agent|
      to_email << agent.email if agent.privilege?(:manage_account)
    end
    to_email
  end

  def trigger_suspended_account_cleanup
    payload =
      {
        job_id: "#{Account.current.id}_suspended_account_cleanup",
        group: ::SchedulerClientKeys['account_cleanup_group_name'],
        scheduled_time: 6.months.from_now.utc,
        data: {
          account_id: Account.current.id,
          enqueued_at: Time.now.to_i
        },
        sqs: {
          url: SQS_V2_QUEUE_URLS[SQS[:suspended_account_cleanup_queue]]
        }
      }
    ::Scheduler::PostMessage.perform_async(payload: payload)
  end

  def account_activated_within_last_week?
    redis_key_exists?(account_activated_within_last_week_key)
  end

  def account_activated_within_last_week_key
    format(ACCOUNT_ACTIVATED_WITHIN_LAST_WEEK, account_id: id)
  end

  def first_time_account_purchased
    set_others_redis_key(account_activated_within_last_week_key, true, 21.days.seconds)
  end

  def fetch_freshsales_account_info(freshsales_app)
    domain = freshsales_app.configs[:inputs]['domain']
    auth_token = freshsales_app.configs[:inputs]['auth_token']
    freshsales_utility = CRM::FreshsalesUtility.new(
      account: self,
      subscription: subscription.attributes.symbolize_keys,
      cmrr: subscription.cmrr
    )
    freshsales_utility.request_account_info(domain, auth_token)
  end

  def freshsales_account_from_freshid
    organisation.organisation_freshsales_account_url if organisation
  rescue StandardError => e
    Rails.logger.debug "Error in getting freshsales account info from freshid. Exception: #{e}, backtrace: #{e.backtrace.join("\n")}"
    nil
  end

  def fetch_fd_fs_banner_details
    fs_account_info = { state: '', url: '' }
    return unless account_additional_settings.additional_settings[:freshdesk_freshsales_bundle]

    freshsales_app = installed_applications.with_name(Integrations::Application::APP_NAMES[:freshsales]).first
    if freshsales_app
      status, response = fetch_freshsales_account_info(freshsales_app)
      if status == 200
        freshsales_domain = response[:accounts].try(:[], 0).try(:[], :full_domain)
        fs_account_info[:url] = format(FRESHSALES_SUBSCRIPTION_URL, domain: freshsales_domain) if freshsales_domain.present?
        fs_account_info[:state] = response[:accounts].try(:[], 0).try(:[], :subscription_state)
      end
    else
      fs_account_info[:state] = freshsales_account_from_freshid.present? ? 'integrate' : 'new'
    end
    fs_account_info
  rescue StandardError => e
    Rails.logger.debug "Error in getting freshsales account info for fd-fs banner. Exception: #{e}, backtrace: #{e.backtrace.join("\n")}"
    nil
  end
end
