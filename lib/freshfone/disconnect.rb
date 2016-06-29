module Freshfone::Disconnect
  
  def initiate_disconnect
    return telephony.no_action if current_call.meta.present? && current_call.meta.missed_response_present?(params[:agent] || params[:agent_id]) # for avoiding multiple missed response coming from different tabs for same agent
    
    params[:CallStatus] = 'no-answer' if params[:AnsweredBy] == 'machine'

    perform_agent_cleanup
    
    #Call Redirect handlers
    handle_agent_missed if current_call.meta.pinged_agents.present? && current_call.meta.all_agents_missed?
    handle_round_robin_calls if round_robin_call?
  
    perform_call_cleanup
    
    current_call.disconnect_customer if (current_call.onhold? && agent_connected? && !child_ringing?(current_call))#fix for: agent disconnect not ending the customer on hold.
  
    telephony.no_action
  end
  
  private

    def perform_agent_cleanup
      update_secondary_leg_response
      update_agent_last_call_at
      reset_outgoing_count
    end

    def perform_call_cleanup
      update_call_duration_and_total_duration if (agent_connected? || external_transfer?) && params[:CallSid].present?
    end

    def handle_agent_missed
      if transfer_call?
        return_missed_transfer
      else
        check_for_queued_calls
        initiate_voicemail unless current_call.noanswer? #means client ended the call.
      end
    end

    def update_secondary_leg_response
      call_actions.update_secondary_leg_response(params[:agent_id] || params[:agent], params[:external_number], params[:CallStatus], current_call)
    end

    def reset_outgoing_count
      remove_device_from_outgoing(split_client_id(params[:From])) if current_call.outgoing? && split_client_id(params[:From]).present?
    end

    def return_missed_transfer
      call_params = params.merge({:DialCallSid => params[:CallSid], :DialCallStatus => params[:CallStatus]})
      call_params.merge!({ :direct_dial_number => format_external_number }) if params[:external_number].present? && params[:external_transfer].present?
      current_call.update_call(call_params)
      notify_source_agent_to_reconnect
    end

    def notify_source_agent_to_reconnect
      notifier.notify_source_agent_to_reconnect(current_call) unless canceled_call?
    end

    def update_call_duration_and_total_duration
      call = params[:external_transfer] == 'true' ?
          current_account.freshfone_calls.find_by_dial_call_sid(params[:CallSid]) : current_call
      return unless call.present? && params[:CallDuration].present?
      call.set_call_duration(params)
      call.save!
    end

    def initiate_voicemail
      freshfone_number = current_call.freshfone_number
      telephony.redirect_call(current_call.call_sid, redirect_caller_to_voicemail(freshfone_number.id))
    end

    def round_robin_call?
      !current_call.transferred_leg? &&
        current_number.round_robin? &&
        current_call.meta.simple_or_group_hunt? &&
        !current_call.meta.all_agents_missed?
    end

    def canceled_call?
      params[:CallStatus] == "canceled"
    end

    def child_ringing?(call)
      child_call = call.children.last
      return if child_call.blank?
      child_call.ringing?
    end

    def telephony # creating new telephony if call is for different number
      self.current_number = current_call.freshfone_number
      if @telephony.present? && @telephony.current_number == current_number
        @telephony.current_call ||= current_call
        return @telephony
      end
      @telephony = Freshfone::Telephony.new(
        params, current_account, current_number, current_call)
    end

    def notifier
      self.current_number = current_call.freshfone_number
      return @notifier if @notifier.present? && @notifier.current_number == current_number
      @notifier = Freshfone::Notifier.new(
        params, current_account, current_user, current_number)
    end

    def call_actions
      self.current_number = current_call.freshfone_number
      return @call_actions if @call_actions.present? && @call_actions.current_number == current_number
      @call_actions = Freshfone::CallActions.new(
        params, current_account, current_number)
    end
end