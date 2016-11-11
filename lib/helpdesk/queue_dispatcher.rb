class Helpdesk::QueueDispatcher
	include Redis::MarketplaceAppRedis

	def initialize(ticket_token)
		@ticket_id 				= ticket_token.split(':').first
		@token			  		= ticket_token.split(':').last
		@ticket_token 		= ticket_token
		@current_account  = Account.current
	end

	def perform
		return error_message unless run_dispatcher?
		@ticket = @current_account.tickets.find_by_display_id(@ticket_id)
		pass_through_biz_rules(@ticket) if valid_ticket?
	rescue Exception => e
		args = { 
			:ticket_id => @ticket_token, 
			:account_id => @current_account.id
		}
		NewRelic::Agent.notice_error(e, { :args => args })
		Rails.logger.error "Error while enqueuing dispatcher \n#{e.message}\n#{e.backtrace.join("\n\t")} #{args}"
		{ :error => [:internal_error, 500, nil] }
	ensure
		complete_dispatcher
	end

	private

		def run_dispatcher?
			# Running dispatcher if it was already skipped.
			@current_account.skip_dispatcher? && get_marketplace_app_redis_key(ticket_key, @ticket_token).present?
		end

		def error_message
			{ :error => @current_account.skip_dispatcher? ? [:marketplace_app_timeout, 403, @ticket_id] : [:require_feature, 403, "marketplace_app"]}
		end		

		def valid_ticket?
			@ticket.present? && automation_params.present? && automation_params.keys.include?("user_id")
		end		

		def automation_params
			@automation_params ||= JSON.parse(get_automation_params_redis_key(params_key, @token))
		end

		def pass_through_biz_rules ticket
			return if (ticket.import_id or ticket.outbound_email?)
			Rails.logger.info "Queued dispatcher for the Account :: #{@current_account.id} ticket :: #{@ticket_id}"

			if @current_account.launched?(:delayed_dispatchr_feature)
				ticket.send_later(:delayed_rule_check, dispatcher_current_user, ticket.freshdesk_webhook?) 
			else
				# This queue includes dispatcher_rules, auto_reply, round_robin.
				Helpdesk::Dispatcher.enqueue(ticket.id, dispatcher_current_user.try(:id), ticket.freshdesk_webhook?)
			end
		end

		def dispatcher_current_user
			@dispatcher_current_user ||= @current_account.all_users.find_by_id(automation_params["user_id"])
		end		

		def complete_dispatcher
			remove_marketplace_app_redis_key(ticket_key, @ticket_token)
			remove_automation_params_redis_key(params_key, @token)
		end

		def ticket_key
			@ticket_key ||= detail_key(@current_account.id) 
		end		

		def params_key
			@params_key ||= automation_params_key(@current_account.id, @ticket_id)
		end		
end