module Freshfone::Conference::TransferMethods

  def initiate_conference_transfer
    if current_call.onhold?
      params[:external_transfer] = "true" unless params[:external_number].blank?
      params[current_call.direction_in_words] = current_call.caller_number #setting parent's caller to child.
      transfer_notifier(current_call, @target_agent_id, @source_agent_id) 
    elsif current_call.inprogress?
      customer_sid = outgoing_transfer?(current_call) ? current_call.root.customer_sid : current_call.customer_sid
      initiate_hold(customer_sid, @target_agent_id, @source_agent_id)
    end
  end

  def initiate_hold(customer_sid, target_agent_id, source_agent_id)
      current_call.onhold!
      telephony.initiate_hold(customer_sid, 
        { :target => target_agent_id, :group_transfer => group_transfer?, :source => source_agent_id, 
          :transfer_type => params[:type], :external_number => params[:external_number],
          :call => current_call.id })
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
        current_call.completed!
        telephony.initiate_agent_conference(
          wait_url: target_agent_wait_url, sid: params[:CallSid])
      rescue Exception => e
        Rails.logger.error "Error in conference transfer success for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        current_call.cleanup_and_disconnect_call
        telephony.no_action
      end
    end

    def cancel_child_call
      current_call.children.last.canceled!
      return telephony.no_action
    end

    def transfer_answered
      @transfer_leg_call.meta.update_pinged_agents_with_response(get_agent_id, 'canceled') if @transfer_leg_call.meta.present?
      telephony.incoming_answered(@transfer_leg_call.agent)
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
      agent_id = new_notifications? ? split_client_id(params[:From]) : split_client_id(params[:To])
    end

    def call_in_progress?
      current_call.inprogress?
    end

    def call_actions
      @call_actions ||= Freshfone::CallActions.new(params, current_account)
    end

end
