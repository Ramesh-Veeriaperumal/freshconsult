module Integrations
  class CtiWorker < ::BaseWorker

    include Sidekiq::Worker
    include Integrations::CtiHelper
    sidekiq_options :queue => :cti, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(call_id)
      begin
        current_account = Account.current
        call = current_account.cti_calls.find(call_id)
        prev_agent_call = current_account.cti_calls.last_agent_call(call)
        if [Integrations::CtiCall::NONE, Integrations::CtiCall::VIEWING].include?(prev_agent_call.status)
          if !prev_agent_call.options[:new_ticket]
            link_call_to_new_ticket(prev_agent_call)
          else
            prev_agent_call.status = Integrations::CtiCall::SYS_CONVERTED
            prev_agent_call.save!
          end
        end
      rescue => e
        Rails.logger.debug "Error occured while processing call id #{call_id} #{e.message} #{e.backtrace.join("\n")}"
        NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occured while processing call id #{call_id} #{e.message}", :account_id => current_account.id}})
      end
    end
  end
end
