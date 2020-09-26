module Freshfone
  class NotificationWorker < BaseWorker
    include Freshfone::FreshfoneUtil
    include Freshfone::Endpoints
    include Freshfone::CallsRedisMethods
    include Freshfone::SubscriptionsUtil
    include Freshfone::CustomForwardingUtil

    sidekiq_options :queue => :freshfone_notifications, :retry => 0, :failures => :exhausted

    attr_accessor :params, :agent, :current_account, :current_number, :telephony

    def perform(params, agent, type)
      Rails.logger.info "Freshfone notification worker"
      Rails.logger.info "JID #{jid} - TID #{Thread.current.object_id.to_s(36)}"
      Rails.logger.info "Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"

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
          when "cancel_other_agents"
            disconnect_other_agents('canceled')
          when "complete_other_agents"
            disconnect_other_agents('completed')
          when "browser_agent_conference"
            notify_browser_agent_conference
          when "mobile_agent_conference"
            notify_mobile_agent_conference
          when "cancel_agent_conference"
            notify_cancel_agent_conference
          when "browser_warm_transfer"
            notify_browser_warm_transfer
          when "mobile_warm_transfer"
            notify_mobile_warm_transfer
          when "cancel_warm_transfer"
            notify_cancel_warm_transfer
        end
        Rails.logger.info "Completion time :: #{Time.now.strftime('%H:%M:%S.%L')}"
      rescue Exception => e
        Rails.logger.error "Error notifying for account #{current_account.id} for type #{type}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        NewRelic::Agent.notice_error(e, {description: "Error in Notification Worker Account #{current_account.id} for type #{type}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
        notify_error(e, params)
      end
    end

    def notify_browser_agents
      Rails.logger.info "Notify Browser for User Id :: #{agent} Account Id :: #{current_account.id}"
      current_call = current_account.freshfone_calls.find_by_conference_sid(params[:ConferenceSid])
      return unless current_call.can_be_connected?
      call_params  = {
        :url             => client_accept_url(current_call.id, agent),
        :status_callback => client_status_url(current_call.id, agent),
        :from            => browser_caller_id(params[:caller_id]),
        :to              => "client:#{agent}",
        :timeout         => current_number.ringing_time,
        :timeLimit       => ::Freshfone::Credit.call_time_limit(current_account, current_call)
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
      Rails.logger.info "Notify Mobile for User Id :: #{agent} Account Id :: #{current_account.id}"
      current_call = @current_account.freshfone_calls.find_by_conference_sid(params[:ConferenceSid])
      return unless current_call.can_be_connected?
      begin 
        from = current_call.number #Showing freshfone number
        to = current_account.users.find(agent).available_number
        call_params  = {
          :url             => mobile_agent_accept_url(current_call.id, agent),
          :status_callback => forward_status_url(current_call.id, agent),
          :from            => get_caller_id(current_call),
          :to              => to_number(from, to, agent),
          :timeout         => current_number.ringing_time,
          :timeLimit       => ::Freshfone::Credit.call_time_limit(current_account, current_call)
        }
        call_params.merge!(if_machine: 'hangup') unless custom_forwarding_enabled?
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
      Rails.logger.info "Notify Browser Transfer for User Id :: #{agent} Account Id :: #{current_account.id}"
      current_call   = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected? || (params[:transfer] == 'true' && current_call.onhold?)
      self.current_number = current_call.freshfone_number
      call_params    = {
        :url             => transfer_accept_url(current_call.id, params[:source_agent_id], agent),
        :status_callback => transfer_status_url(current_call.children.last.id, agent),
        :to              => "client:#{agent}",
        :from            => browser_caller_id(current_call.caller_number),
        :timeLimit       => ::Freshfone::Credit.call_time_limit(current_account, current_call),
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

    def notify_browser_agent_conference
      current_call = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_add_agent?
      Rails.logger.info "Notify Browser Add Agent for User Id :: #{agent}
                         Account Id :: #{current_account.id}"
      self.current_number = current_call.freshfone_number
      call_params = {
        url:               agent_conference_accept_url(params[:call_id],
                                                params[:add_agent_call_id]),
        status_callback:   agent_conference_status_url(params[:call_id],
                                                params[:add_agent_call_id]),
        to:                "client:#{agent}",
        from:              browser_caller_id(current_call.caller_number),
        timeLimit:         ::Freshfone::Credit.call_time_limit(current_account,
                                                               current_call),
        timeout:           current_number.ringing_time
      }
      make_agent_conference_call(call_params, params[:add_agent_call_id], current_call)
    end

    def notify_mobile_agent_conference
      current_call = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_add_agent?
      Rails.logger.info "Notify Mobile Add Agent for User Id :: #{agent}
                         Account Id :: #{current_account.id}"
      from = current_call.number
      to = current_account.users.find(agent).available_number
      call_params = {
        url:             mobile_agent_conference_accept_url(params[:call_id],
                                                    params[:add_agent_call_id]),
        status_callback: agent_conference_status_url(params[:call_id],
                                              params[:add_agent_call_id]),
        to:              to_number(from, to, agent),
        from:            from,
        timeLimit:       ::Freshfone::Credit.call_time_limit(current_account,
                                                             current_call),
        timeout:         current_call.freshfone_number.ringing_time
      }
      call_params.merge!(if_machine: 'hangup') unless custom_forwarding_enabled?
      make_agent_conference_call(call_params, params[:add_agent_call_id], current_call)
    end

    def notify_mobile_transfer
      Rails.logger.info "Notify Mobile Transfer for User Id :: #{agent} Account Id :: #{current_account.id}"
      current_call = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected? || ( params[:transfer] == 'true' && current_call.onhold?)
      freshfone_user = current_account.freshfone_users.find_by_user_id agent
      self.current_number = current_call.freshfone_number
      begin
        from = current_call.number
        to = freshfone_user.available_number
        call_params    = {
          :url             => mobile_transfer_url(current_call.id,
                                                  params[:source_agent_id],
                                                  agent),
          :status_callback => mobile_transfer_status_url(current_call.id, agent),
          :to              => to_number(from, to, agent),
          :from            => get_caller_id(current_call),
          :timeout         => current_number.ringing_time,
          :timeLimit       => ::Freshfone::Credit.call_time_limit(current_account, current_call)
        }
        call_params.merge!(if_machine: 'hangup') unless custom_forwarding_enabled?
        agent_call = telephony.make_call(call_params)
      rescue => e
        call_actions.handle_failed_transfer_call current_call, agent
        raise e
      end
      
      update_and_validate_pinged_agents(current_call.children.last, agent_call) if agent_call.present?
    end

    def notify_browser_warm_transfer
      Rails.logger.info "Notify Browser Warm Transfer for User Id :: #{agent} Account Id :: #{current_account.id}"
      current_call   = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected? || current_call.onhold?
      self.current_number = current_call.freshfone_number
      call_params    = {
        :url             => warm_transfer_accept_url(params[:warm_transfer_call_id], current_call.id),
        :status_callback => transfer_status_url(current_call.id, agent),
        :to              => "client:#{agent}",
        :from            => browser_caller_id(current_call.caller_number),
        :timeLimit       => ::Freshfone::Credit.call_time_limit(current_account, current_call),
        :timeout         => current_number.ringing_time
      }
      begin
        agent_call = telephony.make_call(call_params)
        current_call.supervisor_controls.find(params[:warm_transfer_call_id])
                    .update_details(sid: agent_call.sid)
      rescue => e
        call_actions.handle_failed_warm_transfer(current_call)
        raise e
      end
      if agent_call.present?
        set_browser_sid(agent_call.sid, current_call.call_sid)
      end
    end

    def notify_mobile_warm_transfer
      Rails.logger.info "Notify Mobile Transfer for User Id :: #{agent} Account Id :: #{current_account.id}"
      current_call = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected? || current_call.onhold?
      freshfone_user = current_account.freshfone_users.find_by_user_id agent
      self.current_number = current_call.freshfone_number
      begin
        from = current_call.number
        to = freshfone_user.available_number
        call_params    = {
          :url             => mobile_warm_transfer_accept_url(
                                params[:warm_transfer_call_id],
                                current_call.id),
          :status_callback => transfer_status_url(current_call.id, agent, true),
          :to              => to_number(from, to, agent),
          :from            => get_caller_id(current_call),
          :timeout         => current_number.ringing_time,
          :timeLimit       => ::Freshfone::Credit.call_time_limit(current_account, current_call)
        }
        call_params.merge!(if_machine: 'hangup') unless custom_forwarding_enabled?
        agent_call = telephony.make_call(call_params)
        current_call.supervisor_controls.find(params[:warm_transfer_call_id])
                    .update_details(sid: agent_call.sid)
      rescue => e
        call_actions.handle_failed_warm_transfer current_call
        raise e
      end
    end

    def notify_external_transfer
      Rails.logger.info "Notify External Transfer to Extenal Number :: #{params[:external_number]} for Account Id :: #{current_account.id}"
      current_call   = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected? || (params[:external_transfer] == 'true' && current_call.onhold?)
      self.current_number = current_call.freshfone_number
      begin
        from = current_call.number
        to = format_external_number
        call_params    = {
          :url             => external_transfer_accept(current_call.id, params[:source_agent_id], params[:external_number]),
          :status_callback => external_transfer_complete(current_call.children.last.id, params[:external_number]),
          :timeout         => current_number.ringing_time,
          :to              => to_number(from, to),
          :from            => get_caller_id(current_call),
          :timeLimit       => ::Freshfone::Credit.call_time_limit(current_account, current_call)
        }
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
      Rails.logger.info "Notify Round Robin for User Id :: #{agent['id']} Account Id :: #{current_account.id}"
      current_call   = current_account.freshfone_calls.find(params[:call_id])
      return unless current_call.can_be_connected?
      self.current_number = current_call.freshfone_number
      begin
        from = current_call.number
        to = current_account.users.find(agent["id"]).available_number
        call_params    = {
          :url             => browser_agent? ?
                              round_robin_agent_wait_url(current_call) : 
                              mobile_agent_accept_url(current_call.id, agent["id"]),
          :status_callback => round_robin_call_status_url(current_call, agent["id"], !browser_agent?),
          :from            => browser_agent? ? browser_caller_id(params[:caller_id]) : get_caller_id(current_call),
          :to              => browser_agent? ? "client:#{agent['id']}" : to_number(from, to, agent["id"]),
          :timeout         => current_number.ringing_duration,
          :timeLimit       => ::Freshfone::Credit.call_time_limit(current_account, current_call)
        }
        call_params.merge!(if_machine: 'hangup') if !browser_agent? && !custom_forwarding_enabled?
        agent_call = telephony.make_call(call_params)
      rescue => e
        call_actions.handle_failed_round_robin_call(current_call, agent["id"])
        raise e
      end

      current_call.meta.update_pinged_agent_ringing_at agent['id']
      update_and_validate_pinged_agents(current_call, agent_call)
      set_browser_sid(agent_call.sid, current_call.call_sid) if (browser_agent? && agent_call.present?)
    end

    def notify_direct_dial
      current_call   = current_account.freshfone_calls.find(params[:call_id])
      Rails.logger.info "Notify Direct Dial for Number :: #{current_call.direct_dial_number} for Account Id :: #{current_account.id}"
      return unless current_call.can_be_connected?
      self.current_number = current_call.freshfone_number
      begin
        from = current_call.number
        to = current_call.direct_dial_number
        call_params    = {
          :url             => direct_dial_accept(current_call.id),
          :status_callback => direct_dial_complete(current_call.id),
          :timeout         => current_number.ringing_time,
          :to              => to_number(from, to),
          :from            => get_caller_id(current_call),
          :timeLimit       => current_account.freshfone_credit.direct_dial_time_limit
        }    
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
          Params :: #{params.inspect}<br><br>
          Exception Message :: #{exception.message} <br><br>
          Error Code(if any) :: #{exception.respond_to?(:code) ? exception.code : ''} <br><br>
          Exception Stacktrace :: #{exception.backtrace.join("\n\t")}<br>" })
    end

    def disconnect_api_call(agent_api_call)
      Rails.logger.info "disconnect_api_call :: #{agent_api_call.sid}"
      agent_api_call.update(:status => "completed")
    end

    def notify_cancel_agent_conference
      begin
        current_call = current_account.freshfone_calls.find(params[:call_id])
        add_agent_twilio_call = current_account.freshfone_subaccount.calls
                                               .get(params[:add_agent_call_sid])
        add_agent_twilio_call.update(status: :canceled)
        Rails.logger.info "cancel add agent :: #{params[:add_agent_call_sid]}
                for account :: #{current_account.id}"
      rescue Exception => e
        Rails.logger.error "Error in cancel add agent for account
          #{current_account.id} for call #{params[:add_agent_call_sid]}\n
          #{e.backtrace.join("\n\t")}"
        call_actions.handle_failed_cancel_agent_conference current_call
        raise e
      end
    end

    def notify_cancel_warm_transfer
      begin
        current_call = current_account.freshfone_calls.find(params[:call_id])
        add_agent_twilio_call = current_account.freshfone_subaccount.calls
                                               .get(params[:warm_transfer_call_sid])
        add_agent_twilio_call.update(status: :canceled)
        Rails.logger.info "cancel warm transfer :: #{params[:warm_transfer_call_sid]}
                for account :: #{current_account.id}"
      rescue Exception => e
        Rails.logger.error "Error in cancel warm transfer for account
          #{current_account.id} for call #{params[:warm_transfer_call_sid]}\n
          #{e.backtrace.join("\n\t")}"
        call_actions.handle_failed_warm_transfer_cancel current_call
        raise e
      end
    end

    def update_and_validate_pinged_agents(call, agent_api_call)
      Rails.logger.info "agent call sid update :: Call => #{call.id} :: agent => #{agent} :: call_sid => #{agent_api_call.sid}"
      add_pinged_agents_call(call.id, agent_api_call.sid)
      disconnect_api_call(agent_api_call) if call.meta.reload.any_agent_accepted?      
    end

    def disconnect_other_agents(call_status)
      agent_calls = get_pinged_agents_call(params[:call_id] || params[:call])
      agent_calls.each do |call|
        terminate_api_call(call, call_status) if call.present? && (call != params[:CallSid])
      end
    end

    def terminate_api_call(call_sid, call_status)
      begin
        call = current_account.freshfone_subaccount.calls.get(call_sid)
        call.update(:status => call_status)
        Rails.logger.info "terminate_api_call :: #{call_sid} call_status :: #{call_status}"
      rescue Exception => e
        Rails.logger.error "Error in disconnect_other_agents for account #{current_account.id} for call #{call_sid} for call status : #{call_status}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    end

    # Show Caller's Number if Caller Id Enabled, other wise show Helpdesk Number
    def get_caller_id(call)
      return call.caller_number if current_account.freshfone_account.caller_id_enabled?
      call.number
    end
  private
    def to_number(from, to, agent_id = nil)
      return if from.blank? || to.blank?
      if from.gsub(/\D/, '') == to.gsub(/\D/, '')
        raise "Self calling exception from #{from} to #{to} #{"For User:: #{agent_id}" if agent_id.present?}"
      end
      to
    end

    def make_agent_conference_call(params, add_agent_call_id, current_call)
      begin
        agent_call = telephony.make_call(params)
        current_call.supervisor_controls.find(add_agent_call_id)
                    .update_details(sid: agent_call.sid,
                                    status: Freshfone::SupervisorControl::CALL_STATUS_HASH[:ringing])
      rescue Exception => e
        Rails.logger.error "Error in add agent call for account
          #{current_account.id} for call #{current_call.id} and
          add agent call #{add_agent_call_id}\n #{e.backtrace.join("\n\t")}"
        call_actions.handle_failed_agent_conference current_call, add_agent_call_id
        raise e
      end
    end

    def mobile_agent_accept_url(call_id, agent)
      return custom_accept_url(call_id, agent) if custom_forwarding_enabled?
      forward_accept_url(call_id, agent)
    end

    def mobile_transfer_url(call_id, source_agent_id, agent)
      return custom_mobile_transfer_url(call_id, source_agent_id,
        agent) if custom_forwarding_enabled?
      mobile_transfer_accept_url(call_id, source_agent_id, agent)
    end

    def mobile_agent_conference_accept_url(call_id, add_agent_call_id)
      return custom_agent_conference_url(call_id,
        add_agent_call_id) if custom_forwarding_enabled?
      agent_conference_accept_url(call_id, add_agent_call_id)
    end

    def mobile_warm_transfer_accept_url(warm_transfer_call_id, call_id)
      return custom_warm_transfer_url(warm_transfer_call_id,
        call_id) if custom_forwarding_enabled?
      warm_transfer_accept_url(warm_transfer_call_id, call_id)
    end
  end
end