module Fdadmin::AccountsControllerMethods

	def fetch_account_info(account)
		account_info = {}
		account_info[:name] = account.name
		account_info[:id] = account.id
		account_info[:full_domain] = account.full_domain
		account_info[:created_at] = account.created_at
		account_info[:sso_enabled] = account.sso_enabled
		account_info[:ssl_enabled] = account.ssl_enabled
		account_info
	end

	def fetch_agents_details(account)
		agent_array = []
		account.agents.each do |agent|
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
			billing_cycle: account.subscription.renewal_period
		}
	end

	def fetch_email_details(account)
		mail_array = []
		account.all_email_configs.collect do |em|
			mail_hash = {}
			mail_hash[:name] = em.name
			mail_hash[:reply_email] = em.reply_email
			mail_hash[:active] = em.active
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

end
