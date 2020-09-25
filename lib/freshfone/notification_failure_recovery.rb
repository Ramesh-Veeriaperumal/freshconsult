class Freshfone::NotificationFailureRecovery
	extend Resque::AroundPerform
	extend Freshfone::Endpoints

	@queue = "freshfone_notification_recovery_queue"


	def self.perform(params)
		begin
			Rails.logger.info "Inside NotificationFailureRecovery Job. Params: #{params.inspect}"
			@current_account = Account.current
			@call = @current_account.freshfone_calls.find(params[:call_id])
			return unless @call.ringing?
			Rails.logger.info "Account: #{@current_account.id} Call: #{@call.id} moved to non-availability from NotificationFailureRecovery Job."
			telephony(params).redirect_call(@call.call_sid, redirect_caller_to_voicemail(@call.freshfone_number.id)) if @call.is_root?
			notify_ops
		rescue Exception => e
			Rails.logger.debug "Error when trying to recover notification failure :: \n#{e.message}\n#{e.backtrace.join("\n\t")}"
		end
	end

	private
		def self.notify_ops
			FreshfoneNotifier.deliver_freshfone_ops_notifier(
          @current_account,
          subject: "NotificationFailureRecovery Worker executed",
          message: " Looks like there is an issue in SQS or node server consuming the notification message. 
          Account :: #{(@current_account || {})[:id]} <br>
          Call ID :: #{@call.id} <br>
          Call SID :: #{@call.call_sid}<br>")
		end
		def self.host 
			@host ||= @current_account.url_protocol + "://" + @current_account.full_domain
		end 

		def self.telephony(params)
      number = @call.freshfone_number
      @telephony ||= Freshfone::Telephony.new(params, @current_account, number, @call)
    end
end