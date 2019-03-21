class Account < ActiveRecord::Base

  include MixpanelWrapper
  include Redis::RedisKeys
  include Redis::OthersRedis
  WIN_BACK_PERIOD = 2.freeze
  
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
      CRMApp::Freshsales::DeletedCustomer.perform_async({account_id: self.id}) if Rails.env.production?
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

  def perform_account_cancellation(feedback = {})
    response = Billing::Subscription.new.cancel_subscription(self)
    if response
      cancellation_feedback = "#{feedback[:title]} #{feedback[:additional_info]}"
      send_account_deleted_email(cancellation_feedback)
      update_crm
      create_deleted_customers_info
      send_account_cancelled_email
      clear_account_data
    else 
      Rails.logger.info "Account cancellation failed."
    end
  end
  
  def schedule_account_cancellation_request(feedback)
    SubscriptionNotifier.account_cancellation_requested(feedback) if Rails.env.production?
    job_id = AccountCancelWorker.perform_in(WIN_BACK_PERIOD.days.from_now,{:account_id => self.id})
    set_others_redis_key(self.account_cancellation_request_job_key,job_id,864000)
    renewal_extend if self.subscription.renewal_in_two_days?
  end

  def send_account_cancelled_email
    email_list = self.account_managers.map(&:email).join(',')
    SubscriptionNotifier.admin_account_cancelled(email_list) if Rails.env.production?
  end
  
  def perform_cancellation_for_paid_account
    response = Billing::Subscription.new.cancel_subscription(self)
    if response
      update_crm
      create_deleted_customers_info
      add_churn
      send_account_cancelled_email
      schedule_cleanup
      self.delete_account_cancellation_request_job_key
    else 
      Rails.logger.info "Account cancellation failed."
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
end
