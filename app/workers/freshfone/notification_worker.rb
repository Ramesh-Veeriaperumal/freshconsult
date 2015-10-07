module Freshfone
  class NotificationWorker < BaseWorker
    include Freshfone::FreshfoneUtil
    include Freshfone::CallerLookup
    include Freshfone::Endpoints
    include Freshfone::CallsRedisMethods

    sidekiq_options :queue => :freshfone_notifications, :retry => 0, :backtrace => true, :failures => :exhausted

    attr_accessor :params, :agent, :current_account, :current_number, :telephony

    def perform(params, agent, type)
      Rails.logger.info "Freshfone notification worker"
      Rails.logger.info "JID #{jid} - TID #{Thread.current.object_id.to_s(36)}"
      Rails.logger.info "Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"
      Rails.logger.info "Type :: #{type}"
      Rails.logger.info "#{params}"

      begin
        self.current_account = ::Account.current
        self.params          = params.symbolize_keys!
        self.agent           = agent
        self.current_number  = current_account.freshfone_numbers.find params[:freshfone_number_id] if params[:freshfone_number_id].present?
        self.telephony       = ::Freshfone::Telephony.new(params, current_account, current_number)
        
        case type
          when "browser"
            notify_browser_agents
          when "mobile"
            notify_mobile_agents
          when "browser_transfer"
            notify_browser_transfer
          when "mobile_transfer"
            notify_mobile_transfer
          when "external_transfer"
            notify_external_transfer
          when "round_robin"
            notify_round_robin_agent
          when "direct_dial"
            notify_direct_dial
          when "disconnect_other_agents"
            disconnect_other_agents
        end
        Rails.logger.info "Completion time :: #{Time.now.strftime('%H:%M:%S.%L')}"
      rescue Exception => e
        Rails.logger.error "Error notifying for account #{current_account.id} for type #{type}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        notify_error(e, params)
      end
    end

    def notify_browser_agents
      current_call = current_account.freshfone_calls.find_by_conference_sid(params[:ConferenceSid])
      return unless current_call.can_be_connected?
      call_params  = {
        :url             => client_accept_url(current_call.id, agent),
        :status_callback => client_status_url(current_call.id, agent),
        :from            => browser_caller_id(params[:caller_id]),
        :to              => "client:#{agent}",
        :timeout         => current_number.ringing_time,
        :timeLimit       => current_account.freshfone_credit.call_time_limit
      }

      begin
        agent_call = telephony.make_call(call_params)
      rescue => e
        call_actions.handle_failed_incoming_call current_call, agent
        raise e
      end
      if agent_call.present?
        update_and_validate_pinged_agents(current_call, agent_call)
        set_browser_sid(agent_call.sid, current_call.call_sid)
      end
    end

    def notify_mobile_agents
      current_call = @current_account.freshfone_calls.find_by_conference_sid(params[:ConferenceSid])
      return unless current_call.can_be_connected?
      call_params  = {
        :url             => forward_accept_url(current_call.id, agent),
        :status_callback => forward_status_url(current_call.id, agent),
        :from            => current_call.number, #Showing freshfone number
        :to              => current_account.users.find(agent).available_number,
        :timeout         => current_number.ringing_time,
        :timeLimit       => current_account.freshfone_credit.call_time_limit,
        :if_machine      => "hangup"
      }

      begin
        agent_call = telephony.make_call(call_params)
      rescue => e
        call_actions.handle_failed_incoming_call current_call, agent
        raise e
      end

      if agent_call.present?
        update_and_validate_pinged_agents(current_call, agent_call)
      end
    end

    def notify_browser_transfer
      current_call   = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected? || (params[:transfer] == 'true' && current_call.onhold?)
      self.current_number = current_call.freshfone_number
      call_params    = {
        :url             => transfer_accept_url(current_call.id, params[:source_agent_id], agent),
        :status_callback => transfer_status_url(current_call.children.last.id, agent),
        :to              => "client:#{agent}",
        :from            => browser_caller_id(current_call.caller_number),
        :timeLimit       => current_account.freshfone_credit.call_time_limit,
        :timeout         => current_number.ringing_time
      }
      
      begin
        agent_call = telephony.make_call(call_params)
      rescue => e
        call_actions.handle_failed_transfer_call current_call, agent
        raise e
      end
      
      if agent_call.present?
        update_and_validate_pinged_agents(current_call.children.last, agent_call)
        set_browser_sid(agent_call.sid, current_call.call_sid)
      end
    end

    def notify_mobile_transfer
      current_call   = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected? || ( params[:transfer] == 'true' && current_call.onhold?)
      freshfone_user = current_account.freshfone_users.find_by_user_id agent
      self.current_number = current_call.freshfone_number
      call_params    = {
        :url             => mobile_transfer_accept_url(current_call.id, params[:source_agent_id], agent),
        :status_callback => mobile_transfer_status_url(current_call.id, agent),
        :to              => freshfone_user.available_number,
        :from            => current_call.number, #Showing freshfone number
        :timeout         => current_number.ringing_time,
        :timeLimit       => current_account.freshfone_credit.call_time_limit,
        :if_machine      => "hangup"
      }
      
      begin
        agent_call = telephony.make_call(call_params)
      rescue => e
        call_actions.handle_failed_transfer_call current_call, agent
        raise e
      end
      
      update_and_validate_pinged_agents(current_call.children.last, agent_call) if agent_call.present?
    end

    def notify_external_transfer
      current_call   = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected? || (params[:external_transfer] == 'true' && current_call.onhold?)
      self.current_number = current_call.freshfone_number
      call_params    = {
        :url             => external_transfer_accept(current_call.id, params[:source_agent_id], params[:external_number]),
        :status_callback => external_transfer_complete(current_call.children.last.id, params[:external_number]),
        :timeout         => current_number.ringing_time,
        :to              => params[:external_number],
        :from            => current_call.number, #Showing freshfone number
        :timeLimit       => current_account.freshfone_credit.call_time_limit
      }
      begin
        agent_call = telephony.make_call(call_params)
      rescue => e
        call_actions.handle_failed_external_transfer_call current_call
        raise e
      end
      current_call.children.last.update_call({:DialCallSid  => agent_call.sid})
      add_pinged_agents_call(current_call.children.last.id, agent_call.sid)
      current_call.children.last.meta.reload.update_external_transfer_call(params[:external_number], agent_call.sid) if agent_call.present?
    end

    def notify_round_robin_agent
      current_call   = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected?
      self.current_number = current_call.freshfone_number
      call_params    = {
        :url             => browser_agent? ?
                            round_robin_agent_wait_url(current_call) : 
                            forward_accept_url(current_call.id, agent["id"]),
        :status_callback => round_robin_call_status_url(current_call, agent["id"], !browser_agent?),
        :from            => browser_agent? ? browser_caller_id(params[:caller_id]) : current_call.number,
        :to              => browser_agent? ? "client:#{agent['id']}" : 
                            current_account.users.find(agent["id"]).available_number,
        :timeout         => current_number.ringing_duration,
        :timeLimit       => current_account.freshfone_credit.call_time_limit
      }
      call_params.merge!(:if_machine => 'hangup') unless browser_agent?
      begin
        agent_call = telephony.make_call(call_params)
      rescue => e
        call_actions.handle_failed_incoming_call(current_call, agent['id'])
        raise e
      end
      set_browser_sid(agent_call.sid, current_call.call_sid) if (browser_agent? && agent_call.present?)
    end

    def notify_direct_dial
      current_call   = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected?
      self.current_number = current_call.freshfone_number
      call_params    = {
        :url             => direct_dial_accept(current_call.id),
        :status_callback => direct_dial_complete(current_call.id),
        :timeout         => current_number.ringing_time,
        :to              => current_call.direct_dial_number,
        :from            => current_call.number, #Showing freshfone number
        :timeLimit       => current_account.freshfone_credit.direct_dial_time_limit
      }
      begin
        direct_dial = telephony.make_call(call_params)
      rescue => e
        call_actions.handle_failed_direct_dial_call current_call
        raise e
      end
      current_call.update_attributes(:dial_call_sid => direct_dial.sid)
    end

    def browser_agent?
      agent["device_type"] == "browser"
    end

    def call_actions
      @call_actions ||= Freshfone::CallActions.new(params, current_account, current_number)
    end

    def notify_error(exception, params)
      FreshfoneNotifier.freshfone_email_template(current_account,{
          :recipients => FreshfoneConfig['ops_alert']['mail']['to'],
          :from       => FreshfoneConfig['ops_alert']['mail']['from'],
          :subject    => "Conference Notification failure",
          :message    => "Account :: #{(current_account || {})[:id]} <br>
          Number Id :: #{(current_number || {})[:id]}<br>
          Number :: #{(current_number || {})[:number]}<br>
          Params :: #{params}<br><br>
          Exception Message :: #{exception.message} <br><br>
          Error Code(if any) :: #{exception.respond_to?(:code) ? exception.code : ''} <br><br>
          Exception Stacktrace :: #{exception.backtrace.join("\n\t")}<br>" })
    end

    def disconnect_api_call(agent_api_call)
      Rails.logger.info "disconnect_api_call :: #{agent_api_call.sid}"
      agent_api_call.update(:status => "completed")
    end

    def update_and_validate_pinged_agents(call, agent_api_call)
      Rails.logger.info "agent call sid update :: Call => #{call.id} :: agent => #{agent} :: call_sid => #{agent_api_call.sid}"
      add_pinged_agents_call(call.id, agent_api_call.sid)
      disconnect_api_call(agent_api_call) if call.meta.reload.any_agent_accepted?      
    end

    def disconnect_other_agents
      agent_calls = get_pinged_agents_call(params[:call_id])
      agent_calls.each do |call|
        terminate_api_call(call) if call.present? && (call != params[:CallSid])
      end
    end

    def terminate_api_call(call_sid)
      begin
        call = current_account.freshfone_subaccount.calls.get(call_sid)
        call.update(:status => "canceled")
        Rails.logger.info "terminate_api_call :: #{call_sid}"
      rescue Exception => e
        Rails.logger.error "Error in disconnect_other_agents for account #{current_account.id} for call #{call_sid}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    end

  end
end