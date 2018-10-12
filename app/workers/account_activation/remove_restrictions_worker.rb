class AccountActivation::RemoveRestrictionsWorker < BaseWorker
	include Sidekiq::Worker
	sidekiq_options :queue => :activation_worker, :retry => 5, :backtrace => true, :failures => :exhausted

	def perform(args = {})
		activate_notifications
		activate_restricted_rules
	rescue Exception => e
		puts e.inspect, args.inspect
		NewRelic::Agent.notice_error(e, {:args => args})
		raise e
	end

	def activate_notifications    
		notifications = Account.current.email_notifications
		# make all agent related notifications true except ticket created upon activation
		notifications.select{|n| n.visible_to_agent? && n.notification_type != EmailNotification::NEW_TICKET}.each do |n|
			n.update_attribute(:agent_notification,true)
		end
		# Commenting this as users will be prompted to turn them on through the trial widget
		# make all requested related notifications true upon activation
		# notifications.select{|n|  !n.visible_only_to_agent?}.each do |n|
		# 	n.update_attribute(:requester_notification,true)
		# end
	end

	def activate_restricted_rules
		restricted_rules = Account.current.account_va_rules.with_send_email_actions
		restricted_rules.each do |rule|
				rule.update_attribute(:active, true)
		end
	end

end
