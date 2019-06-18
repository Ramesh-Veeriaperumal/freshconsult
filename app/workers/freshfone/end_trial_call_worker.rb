module Freshfone
  class EndTrialCallWorker < BaseWorker

    sidekiq_options :queue => :freshfone_trial_worker, :retry => 0, :failures => :exhausted

    def perform(params)
      Rails.logger.info "Freshfone End Trial Call worker"
      Rails.logger.info "JID #{jid} - TID #{Thread.current.object_id.to_s(36)}"
      Rails.logger.info "Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"
      Rails.logger.info "#{params.inspect}"

      params.symbolize_keys!
      calls_to_be_ended = ::Account.current
                          .freshfone_calls
                          .inprogress_trial_calls(params[:call_type])
      calls_to_be_ended.each do |call|
        begin
          call.disconnect_customer # disconnecting customer will automatically disconnect agent
        rescue => e
          Rails.logger.error "Error while ending trial calls for Call Type ::
            #{Freshfone::Call::CALL_TYPE_REVERSE_HASH[params[:call_type]]}
            For Account Id :: #{::Account.current.id} For Call SId :: #{call.call_sid}\n
          Exception Message :: #{e.message}\nException Stacktrace :: #{e.backtrace.join('\n\t')}"
          NewRelic::Agent.notice_error(e, {description: "Error in End Trial Call Worker for Account #{::Account.current.id} Call SId :: #{call.call_sid}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
        end
      end
    rescue => e
      Rails.logger.error "Error on End Trial Call
        For Account ::#{::Account.current.id}\n
        Exception Message :: #{e.message}\nException Stacktrace :: #{e.backtrace.join('\n\t')}"
        NewRelic::Agent.notice_error(e, {description: "Error in End Trial Call Worker for Account #{::Account.current.id} Call SId :: #{call.call_sid}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
    end
  end
end
