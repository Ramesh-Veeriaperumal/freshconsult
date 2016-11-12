module Fdadmin::AccountsControllerMethods
	include Redis::RedisKeys
	include Redis::IntegrationsRedis

	def fetch_account_info(account)
		account_info = {}
		account_info[:name] = account.name
		account_info[:id] = account.id
		account_info[:full_domain] = account.full_domain
		account_info[:created_at] = account.created_at
		account_info[:sso_enabled] = account.sso_enabled
		account_info[:ssl_enabled] = account.ssl_enabled
		account_info[:time_zone] = account.time_zone
		account_info
	end

	def fetch_agents_details(account)
		agent_array = []
		account.agents.includes(:user).each do |agent|
			agent_hash = {}
			agent_hash[:email] = agent.user.email
			agent_hash[:active] = agent.user.active
			agent_hash[:occasional] = agent.occasional
			agent_array << agent_hash
		end
		return {  free_agents: account.subscription.free_agents,
							agent_limit: account.subscription.agent_limit,
							full_time: account.full_time_agents.count,
							total_agents: account.agents.count,
							agents_detail: agent_array
							}

	end

	def fetch_subscription_account_details(account)
		return {
			state: account.subscription.state ,
			plan_name:account.subscription.subscription_plan.name,
			revenue: account.subscription.cmrr,
			next_renewal: account.subscription.next_renewal_at,
			amount: account.subscription.amount,
			billing_cycle: account.subscription.renewal_period,
			subscription_plan_id: account.subscription.subscription_plan_id
		}
	end

	def fetch_email_details(account)
		mail_array = []
		account.all_email_configs.collect do |em|
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
		account.tickets.find(:all,:order => 'created_at desc',:limit => 5).each do |tkt|
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

	def get_account_details(account)
	  ff_account = account.freshfone_account
	  ff_credit = account.freshfone_credit
	  return { available_credit: 0.00 } if only_freshfone_feature?(account)
	  return active_account_details(ff_credit) if freshfone_active?(ff_account) ||
	                                              ff_credit.present?

	  { trial_started:  ff_account.present? && ff_account.trial_or_exhausted?,
	   activation_requested: freshfone_activation_requested?(account) }
	end

	def active_account_details(ff_credit)
		{ available_credit: ff_credit.present? ? ff_credit.available_credit : 0.00 }
	end

	def freshfone_activation_requested?(account)
	  get_key(FRESHFONE_ACTIVATION_REQUEST % { account_id: account.id }).present?
	end

	def only_freshfone_feature?(account)
	  account.features?(:freshfone) && account.freshfone_account.blank? &&
	  	account.freshfone_credit.blank?
	end

	def freshfone_active?(ff_account)
	  ff_account.present? && ff_account.active?
	end
end
