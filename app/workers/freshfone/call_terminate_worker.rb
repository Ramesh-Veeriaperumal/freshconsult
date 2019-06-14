module Freshfone
  class CallTerminateWorker < BaseWorker

    sidekiq_options queue: :freshfone_trial_worker, retry: 0,
                    failures: :exhausted

    attr_accessor :params, :current_account

    def perform(params)
      Rails.logger.info 'Call Terminate Worker'
      Rails.logger.info "JID #{jid} - TID #{Thread.current.object_id.to_s(36)}"
      Rails.logger.info "Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"
      Rails.logger.info "#{params.inspect}"

      enqueued_time = params[:enqueued_time]
      if enqueued_time
        job_latency = Time.now - Time.parse(enqueued_time)
        return if job_latency > 60
      end

      begin
        self.current_account = ::Account.current
        self.params = params.symbolize_keys!

        current_call = current_account.freshfone_calls.find(params[:call_id])
        Rails.logger.info "Disconnecting Call::#{current_call.id} DialCallSid::#{current_call.dial_call_sid} for Account::#{current_account.id} from Call Terminate Worker."
        current_call.disconnect_customer
      rescue => e
        Rails.logger.error "Error in Call Terminate Worker for account #{params[:account_id]}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        NewRelic::Agent.notice_error(e, {description: "Error in Call Terminate Worker for account #{params[:account_id]}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
        notify_error(e)
      ensure
        ::Account.reset_current_account
      end
    end

    def notify_error(exception)
      return if current_account.blank?
      Rails.logger.info "Call Terminate Worker account additional settings :
        #{params[:account_id]} : #{current_account.id} :
        #{current_account.account_additional_settings.present?}"
      return if current_account.account_additional_settings.blank?
      FreshfoneNotifier.freshfone_ops_notifier(current_account,
        subject: 'Call Terminate Worker failure',
        message: "Account :: #{params[:account_id]} <br>
        Params :: #{params.inspect}<br><br>
        Exception Message : #{exception.message}<br><br>
        Stacktrace :: #{exception.backtrace.join("\n\t")}<br>")
    end
  end
end