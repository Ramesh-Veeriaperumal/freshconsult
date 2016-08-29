module Freshfone
  module WarmTransferDisconnect

    def handle_warm_transfer_end_call
      handle_warm_transfer_source if warm_transfer_source_agent? 
      handle_warm_transfer_call if warm_transfer_target_agent?
      notify_warm_transfer_busy(params[:CallStatus])
      reset_presence(current_call.agent) if current_call.agent.present? && current_call.agent.available_on_phone?
    end

    def handle_warm_transfer_source
      return if current_call.completed?
      update_current_call
      update_warm_transfer_leg(true)
      child_call = create_child_call
      notifier.notify_warm_transfer_status(current_call, 'update_presence')
      notifier.notify_warm_transfer_status(child_call, 'parent_call_completed')
      redirect_customer(child_call)
    end

    def handle_warm_transfer_call
      return if current_call.completed?
      warm_transfer_user = warm_transfer_call.supervisor
      update_current_call
      update_warm_transfer_leg
      update_participant_cost
      update_warm_transfer_duration
      child_call = create_child_call(true)
      notifier.notify_warm_transfer_status(current_call, 'update_presence')
      notifier.notify_warm_transfer_status(child_call, 'warm_transfer_reverted')
      redirect_agent(child_call)
      reset_presence(warm_transfer_user) if warm_transfer_user.available_on_phone?
    end

    private

    def redirect_customer(call)
      return if call.blank?
      telephony.redirect_call_to_conference(warm_transfer_supervisor_leg.sid,
                                          join_agent_url(call.id))
    end

    def redirect_agent(call)
      telephony.redirect_call_to_conference(call.agent_sid, join_agent_url(call.id))
    end

    def warm_transfer_source_agent?
      warm_transfer_supervisor_leg.present? &&
        (warm_transfer_call.blank? || !warm_transfer_call.inprogress?) &&
        warm_transfer_supervisor_leg.inprogress?
    end

    def reset_presence(user)
      user.freshfone_user.reset_presence.save!
    end

    def warm_transfer_target_agent?
      warm_transfer_call.present? && warm_transfer_call.inprogress?
    end

    def disconnect_warm_transfer(call)
      return unless split_client_id(params[:From]).blank? && call.present?
      disconnect_call(call)
      call.update_details(
        status: Freshfone::SupervisorControl::CALL_STATUS_HASH[:completed])
    end

    def disconnect_call(warm_transfer_call)
      return notifier.cancel_warm_transfer(warm_transfer_call, current_call) if new_notifications? && warm_transfer_call.default?
      current_account.freshfone_subaccount.calls.get(warm_transfer_call.sid).update(status: :completed)
    end

    def update_participant_cost
      return if warm_transfer_call.duration.present?
      warm_transfer_call.update_details(CallDuration: params[:CallDuration])
    end

    def notify_warm_transfer_busy(status)
      return if warm_transfer_call.blank? || status == 'completed'
      create_child_call.update_call(DialCallStatus: status)
      notifier.notify_warm_transfer_status(current_call, 'warm_transfer_status',
          status) && update_warm_transfer_leg if ['no-answer','busy'].include?(status)
      warm_transfer_call.update_details(
        status: Freshfone::SupervisorControl::CALL_STATUS_HASH[status.to_sym]
        ) if status == 'canceled'
    end

    def update_warm_transfer_duration
      current_call.total_call_duration
    end

    def update_current_call
      call_params = params.merge({:DialCallStatus => params[:CallStatus]})
      current_call.update_call(call_params)
    end

    def update_warm_transfer_leg(parent_call = false)
      return update_parent_leg if parent_call
      warm_transfer_call.update_details(CallDuration: params[:CallDuration],
        status: Freshfone::SupervisorControl::CALL_STATUS_HASH[params[:CallStatus].to_sym])
    end

    def active_warm_transfer_call
       current_call.supervisor_controls.warm_transfer_calls.initiated_or_inprogress_calls.first
    end

    def update_parent_leg
       warm_transfer_supervisor_leg.update_duration_and_status(params[:CallStatus])
    end

    def warm_transfer_call
      @warm_transfer_call ||= current_account.supervisor_controls.find_by_sid(params[:CallSid])
    end

    def warm_transfer_supervisor_leg
      @supervisor_call ||= current_call.supervisor_controls
                                       .warm_transfer_calls.initiated_or_inprogress_calls.last
    end

    def warm_transfer_disconnect?
      current_call.meta.warm_transfer_meta?
    end

    def child_ringing?(call)
      child_call = call.children.last
      return if child_call.blank?
      child_call.ringing?
    end
   
    def create_child_call(reverted = false)
      call = current_call.has_children? ? current_call.get_child_call : current_call
      child_call = call.build_warm_transfer_child(build_child_params(reverted))
      current_call.root.increment(:children_count).save && create_meta(child_call, reverted) if child_call.save
      child_call
    end

    def create_meta(call, reverted)
      call.create_meta(select_meta_params(call, reverted))
    end

    def select_meta_params(call, reverted)
      return meta_params if reverted
      warm_transfer_meta_params(call)
    end

    def meta_params
      meta = current_call.meta
      { account: current_call.account, device_type: meta.device_type,
        meta_info: meta.meta_info.merge!(:type => 'warm_transfer'),
        hunt_type: meta.hunt_type, pinged_agents: meta.pinged_agents }
    end

    def warm_transfer_meta_params(call)
      user =  current_account.freshfone_users.find_by_user_id(call.user_id)
      { account: current_call.account, meta_info: current_call.meta.meta_info,
        transfer_by_agent: current_call.user_id,
        hunt_type: Freshfone::CallMeta::HUNT_TYPE_HASH[:agent],
        meta_info: { :type => 'warm_transfer' },
        pinged_agents: [{ id: user.user_id, ff_user_id: user.id, name: user.name,
                        device_type: user.available_on_phone? ? :mobile : :browser }]}
    end

    def build_child_params(reverted)
      return reverted_child_call_sid.merge!(agent: current_call.agent) if reverted
      child_params = { agent: warm_transfer_supervisor_leg.supervisor }
      child_params.merge!(update_child_call_sid)
      child_params
    end

    def reverted_child_call_sid
      return { call_sid: current_call.dial_call_sid, 
        dial_call_sid: current_call.root.customer_sid } if outgoing_or_warm_transfer?(current_call)
      { call_sid: current_call.call_sid, dial_call_sid: current_call.dial_call_sid }
    end

    def update_child_call_sid
      return { call_sid: current_call.customer_sid, dial_call_sid: warm_transfer_supervisor_leg.sid } if current_call.incoming?
      { call_sid: warm_transfer_supervisor_leg.sid, dial_call_sid: select_outgoing_customer_sid }
    end

    def select_outgoing_customer_sid
      outgoing_or_warm_transfer?(current_call) ? current_call.root.dial_call_sid : current_call.customer_sid
    end

    def notifier
      current_number = current_call.freshfone_number
      return @notifier if @notifier.present? && @notifier.current_number == current_number
      @notifier = Freshfone::Notifier.new(
        params, current_account, current_user, current_number)
    end

  end
end
