module Freshfone::Conference::TransferMethods
  include Freshfone::CallsRedisMethods

  def initiate_conference_transfer
    if current_call.onhold?
      params[:external_transfer] = "true" unless params[:external_number].blank?
      params[current_call.direction_in_words] = current_call.caller_number #setting parent's caller to child.
      params[:call] = current_call.id
      transfer_notifier(current_call, @target_agent_id, @source_agent_id) 
    elsif current_call.inprogress?
      initiate_hold(blind_transfer_hold_params)
    end
  end

  def initiate_hold(hold_params)
      current_call.onhold!
      customer_sid = outgoing_or_warm_transfer?(current_call) ? current_call.root.customer_sid : current_call.customer_sid
      telephony.initiate_hold(customer_sid, hold_params)
  end

  def telephony(call = current_call)
    current_number = call.freshfone_number
    @telephony = Freshfone::Telephony.new(params, current_account, current_number, call)
  end

  private

    def handle_transfer_success
      begin
        notifier.notify_transfer_success(current_call)
        notifier.cancel_other_agents transfer_leg
        current_call.children.last.inprogress!
        current_call.completed!
        telephony.initiate_agent_conference(
          wait_url: target_agent_wait_url, sid: params[:CallSid])
      rescue Exception => e
        Rails.logger.error "Error in conference transfer success for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        current_call.cleanup_and_disconnect_call
        no_action
      end
    end

    def blind_transfer_hold_params
      { :target => @target_agent_id, :group_transfer => group_transfer?, :source => @source_agent_id, 
        :transfer_type => params[:type], :external_number => params[:external_number],
        :call => current_call.id }
    end

    def handle_warm_transfer_success
      notifier.notify_warm_transfer_status(current_call, 'warm_transfer_success')
      agent_sid = outgoing_or_warm_transfer?(current_call) ? current_call.dial_call_sid : current_call.agent_sid
      telephony.redirect_call_to_conference(agent_sid,
                   redirect_source_url(warm_transfer_leg.id))
      telephony.initiate_conference(target_agent_conf_params)
    end

    def target_agent_conf_params
      { sid: "#{params[:CallSid]}_warm_transfer", startConferenceOnEnter: true, beep: true,
        endConferenceOnExit: false }
    end

    def clear_client_calls
      key = FRESHFONE_CLIENT_CALL % { :account_id => current_account.id }
      remove_from_set(key, current_call.call_sid)
    end

    def warm_transfer_leg
      @warm_transfer_call ||= current_account.supervisor_controls.find(params[:warm_transfer_call_id])
    end

    def cancel_child_call
      current_call.children.last.canceled!
      no_action
    end

    def transfer_answered
      # @transfer_leg_call.meta.update_pinged_agents_with_response(get_agent_id, 'canceled') if @transfer_leg_call.meta.present?
      set_agent_response(current_account.id, @transfer_leg_call.id, get_agent_id, 'canceled')
      transfer_answered_twiml
    end

    def intended_agent_for_transfer?
      @transfer_leg_call = current_call.children.last
      return true if @transfer_leg_call.user_id.blank?
      @transfer_leg_call.user_id.to_s == get_agent_id
    end

    def transfer_leg
      fetch_and_update_child_call(params[:call], params[:CallSid], get_agent)
    end

    def get_agent
      split_client_id(params[:From])
    end

    def call_in_progress?
      current_call.inprogress?
    end

    def call_actions
      @call_actions ||= Freshfone::CallActions.new(params, current_account)
    end

    def no_action
      telephony.no_action
    end

    def transfer_answered_twiml
      telephony.incoming_answered(@transfer_leg_call.agent)
    end
end
