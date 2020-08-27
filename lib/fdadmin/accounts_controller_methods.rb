module Fdadmin::AccountsControllerMethods

  include Redis::RedisKeys
  include Redis::IntegrationsRedis
  include Fdadmin::ApiConstants

	def fetch_account_info(account)
		account_info = {}
		account_info[:name] = account.name
		account_info[:id] = account.id
		account_info[:full_domain] = account.full_domain
		account_info[:created_at] = account.created_at
		account_info[:sso_enabled] = account.sso_enabled
		account_info[:ssl_enabled] = account.ssl_enabled
		account_info[:time_zone] = account.time_zone
		account_info[:language] = account.language
		account_info
	end

 def fetch_agents_details(account)
   agent_array = []
   field_agent_array = []
   fsm_enabled = account.field_service_management_enabled?
   field_agent_type = AgentType.agent_type_id(Agent::FIELD_AGENT) if fsm_enabled
   account.agents.includes(user: :user_emails).find_each(batch_size: 100) do |agent|
     agent_hash = {}
     agent_hash[:email] = agent.user.email
     agent_hash[:active] = (agent.user.active && agent.user.user_emails.first.verified?)
     agent_hash[:created_at] = agent.created_at
     agent_hash[:last_active] = agent.last_active_at
     if agent.agent_type == Agent::SUPPORT_AGENT_TYPE
       agent_hash[:occasional] = agent.occasional
       agent_hash[:is_admin] = agent.user.privilege?(:admin_tasks)
       agent_array << agent_hash
     elsif fsm_enabled && agent.agent_type == field_agent_type
       field_agent_array << agent_hash
     end
   end
   response_data = { free_agents: account.subscription.free_agents,
                     agent_limit: account.subscription.agent_limit,
                     full_time: account.full_time_support_agents.count,
                     occasional_agents: account.agents.occasional_agents.count,
                     total_agents: account.agents.count,
                     agents_detail: agent_array }
   if fsm_enabled
     response_data[:field_agents] = field_agent_array.count
     response_data[:field_agents_details] = field_agent_array
   end
   response_data
 end

  def fetch_subscription_account_details(account)
    {
      state: account.subscription.state,
      plan_name: account.subscription.subscription_plan.name,
      plan_display_name: account.subscription.subscription_plan.display_name,
      mode: subscription_payment_mode(account),
      revenue: account.subscription.cmrr,
      next_renewal: account.subscription.next_renewal_at,
      amount: account.subscription.amount,
      billing_cycle: account.subscription.renewal_period,
      subscription_plan_id: account.subscription.subscription_plan_id,
      paid_account: account.subscription.non_new_sprout? && account.subscription_payments.count != 0,
      agent_seats: account.subscription.agent_limit == Fdadmin::BillingController::DEFAULT_AGENT_LIMIT ? account.full_time_support_agents.count : account.subscription.agent_limit,
      fsm_agents: account.subscription.field_agent_limit || 0
    }
  end

	def fetch_email_details(account)
		mail_array = []
		account.all_email_configs.preload([:imap_mailbox, :smtp_mailbox]).collect do |em|
			mail_hash = {}
			mail_hash[:name] = em.name
			mail_hash[:reply_email] = em.reply_email
			mail_hash[:active] = em.active
			mail_hash[:imap_mailbox_configured] = !em.imap_mailbox.nil? 
			mail_hash[:imap_mailbox_enabled] = em.imap_mailbox.enabled if mail_hash[:imap_mailbox_configured] 
			mail_hash[:smtp_mailbox_configured] = !em.smtp_mailbox.nil?
			mail_hash[:smtp_mailbox_enabled] =  em.smtp_mailbox.enabled if mail_hash[:smtp_mailbox_configured] 
			mail_array << mail_hash
		end
		mail_array
	end

	def fetch_portal_details(account)
		port_array = []
		account.portals.collect do |port|
			portal_hash = {}
			portal_hash[:name] = port.name
			portal_hash[:portal_url] = port.portal_url
			portal_hash[:language] = port.language
			port_array << portal_hash
		end
		port_array
	end

	def fetch_invoice_emails(account)
		invoice_mails = []
		account.invoice_emails.each do |email|
			invoice_mails << email
		end
	end

	def fetch_currency_details(account)
		return {  name: account.currency_name ,
							billing_site: account.subscription.currency_billing_site
							}
	end

	def fetch_ticket_details(account)
		ticket_array = []
		account.tickets.order('created_at desc').limit(5).each do |tkt|
			ticket_array << tkt.subject
		end
		return { ticket_count: account.tickets.count,
						 sample_tickets: ticket_array
						 }
	end

	def fetch_social_info(account)
		return {  facebook: !account.facebook_pages.blank?,
							twitter: !account.twitter_handles.blank?
							}
	end

	def active_account_details(ff_credit)
		{ available_credit: ff_credit.present? ? ff_credit.available_credit : 0.00 }
	end

	def freshfone_activation_requested?(account)
	  get_key(FRESHFONE_ACTIVATION_REQUEST % { account_id: account.id }).present?
	end
	
	def validate_new_currency
		subscription = Account.current.subscription
		return false if subscription.currency_name == params[:new_currency]
		subscription.currency = Subscription::Currency.find_by_name(params[:new_currency])
		result = subscription.billing.retrieve_subscription(subscription.account_id)
		result.subscription.status.include?("trial")
	rescue	
	end

	def do_trial_extend(days)
		subscription = Account.current.subscription
		if ["trial", "suspended"].include?(subscription.state)
			data = {:trial_end => days.from_now.utc.to_i}
			result = Billing::ChargebeeWrapper.new.update_subscription(subscription.account_id, data)
			return unless result.subscription.status.eql?("in_trial")
			subscription.next_renewal_at = days.from_now.utc
			subscription.state = "trial"
			subscription.save!
		end
	rescue
	end
	
	def switch_currency
		account = Account.current
		subscription = account.subscription.reload
		result = Billing::Subscription.new.cancel_subscription(account)
		if result.subscription.status == "cancelled"
			subscription.currency = Subscription::Currency.find_by_name(params[:new_currency])
			subscription.save!
		end
	end

  def fetch_fluffy_details(account)
    { enabled: account.fluffy_enabled? }
  end

  def fluffy_api_v2_limit(account)
    data = account.current_fluffy_limit(account.full_domain) if account.fluffy_integration_enabled?
    data.present? ? { limit: data.limit, granularity: data.granularity } : {}
  end

  def trigger_enable_old_ui_action
    ::InternalService::FreshopsOperations.perform_async(params)
  end

  def trigger_daypass_export_action
  	::InternalService::FreshopsOperations.perform_async(params)
  end

  def trigger_stop_account_cancellation_action
    account = Account.find(params[:account_id])
    account.make_current
    account.kill_account_cancellation_request_job
  end

  def trial_subscription_hash(trial_subscription)
    return {} if trial_subscription.blank?

    {
        status: TrialSubscription::TRIAL_STATUSES.key(trial_subscription.status),
        created_at: trial_subscription.created_at.to_date,
        ends_at: trial_subscription.ends_at.to_date,
        upsell_plan: trial_subscription.trial_plan
    }
  end

  def fetch_requested_subscription_details(subscription_request)
    return {} if subscription_request.blank?
    {
      created_at: subscription_request.created_at,
      from_plan: subscription_request.subscription.plan_name,
      to_plan: subscription_request.plan_name,
      to_plan_cost: SubscriptionPlan.find(subscription_request.plan_id).amount,
      agent_seats: subscription_request.agent_limit,
      renewal_period: subscription_request.renewal_period,
      fsm_agents: subscription_request.fsm_field_agents || 0
    }
  end

  def fetch_account_cancellation_requested_time(account)
    Time.zone.at(account.account_cancellation_requested_time.to_i / 1000).utc.to_date if account.account_cancellation_requested?
  end

  private

    def subscription_payment_mode(account)
      return nil if account.subscription.free?

      account.subscription.card_number.present? ? CARD_PAYMENT : OFFLINE_PAYMENT
    end
end
