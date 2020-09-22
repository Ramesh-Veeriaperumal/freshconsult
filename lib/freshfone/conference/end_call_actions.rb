module Freshfone::Conference::EndCallActions
   include Freshfone::WarmTransferDisconnect

  def complete_call
    begin
      if warm_transfer_enabled?
        disconnect_warm_transfer
        return handle_warm_transfer if warm_transfer_source_agent?
      end

      return empty_twiml if current_call.blank?
      return complete_transfer_leg if transfered_call_end? || external_transfer_call?
      handle_sip_end_call if current_call.sip?

      current_call.disconnect_customer if current_call.onhold?
      current_call.disconnect_agent
      disconnect_agent_conference(active_agent_conference_call.sid) if active_agent_conference_call.present?
      current_call.update_call(params) if !params[:To].empty? || single_leg_outgoing? #Outgoing issue fix. Explanation in spreadsheet: F59
      disconnect_ringing if still_ringing? 
    rescue Exception => e
      Rails.logger.error "Error in completing Conference call for #{params[:CallSid]} :: #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      current_call.disconnect_agent
    end
    empty_twiml
  end


  def complete_transfer_leg
    params[:DialCallStatus] = "completed"
    call = external_transfer_call? ? current_call : current_call.descendants.last
    call = call.parent if outgoing_transfer_missed?(call) # if child call is missed or busy, then the params are for the parent call in outgoing.
    call.update_call(params)
    disconnect_parent_call?(call) ? call.parent.disconnect_agent : call.disconnect_agent
    empty_twiml
  end

  private

    def external_transfer_call?
      !current_call.is_root? && current_call.direct_dial_number.present? && current_call.incoming?
    end

    def transfered_call_end?
      current_call.completed? && current_call.has_children? && current_call.descendants.present?
    end

    def handle_warm_transfer
      return if params[:agent_id].present?
      handle_warm_transfer_source
      empty_twiml
    end

    def single_leg_outgoing?
      current_call.present? && current_call.outgoing_root_call? && current_call.descendants.blank?
    end

    def outgoing_leg?
      return warm_transfer_leg_outgoing? if warm_transfer_enabled?
      single_leg_outgoing?
    end

    def warm_transfer_leg_outgoing?
      current_call.present? && current_call.outgoing? && 
          ((current_call.is_root? && current_call.descendants.blank?) || current_call.meta.warm_transfer_meta?)
    end

    def disconnect_ringing
      return telephony.disconnect_call(current_call.dial_call_sid) if single_leg_outgoing? # customer call end
      cancel_ringing_agents
    end

    def cancel_ringing_agents
      return if current_call.blank? || current_call.meta.blank?
      #To cancel both browser and mobile agents in case of new notifications
      jid = Freshfone::RealtimeNotifier.perform_async({ call_id: current_call.id }, current_call.id, nil, 'cancel_other_agents')
      Rails.logger.info "Account ID : #{current_account.id} - cancel_ringing_agents : Sidekiq Job ID #{jid} - TID #{Thread.current.object_id.to_s(36)}"
      Freshfone::NotificationWorker.perform_async({ call_id: current_call.id }, nil, 'cancel_other_agents')
      current_call.meta.cancel_browser_agents
    end

    def active_agent_conference_call
      current_call.supervisor_controls.agent_conference_calls([Freshfone::SupervisorControl::CALL_STATUS_HASH[:default],
                                                               Freshfone::SupervisorControl::CALL_STATUS_HASH[:ringing]]).first
    end

    def active_warm_transfer_call
       return if current_call.blank?
       @active_warm_transfer_call ||= current_call.supervisor_controls.warm_transfer_calls.initiated_or_inprogress_calls.first
    end

    def disconnect_agent_conference(call_sid)
      Freshfone::NotificationWorker.perform_async({:add_agent_call_sid => call_sid, :call_id => current_call.id}, nil, 'cancel_agent_conference')
    end

    def still_ringing?
      current_call.ringing? ||
        (current_call.incoming? && current_call.noanswer?) ||
          (single_leg_outgoing? && current_call.dial_call_sid.present?)
    end

    def outgoing_transfer_missed?(call)
      current_call.outgoing? && transfer_missed?(call)
    end

    def add_preview_cost_job
      cost_params = { :account_id => current_account.id,
        :call_sid => params[:CallSid],
        :billing_type => Freshfone::OtherCharge::ACTION_TYPE_HASH[:ivr_preview] }
      Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, cost_params)
    end

    def sip_user
      current_call.user_id
    end
                                                                       
    def handle_sip_end_call
      freshfone_user = current_account.freshfone_users.find_by_user_id sip_user
      return if freshfone_user.blank?
      freshfone_user.reset_presence.save!
    end

     def set_agent
      params[:agent] = split_client_id(params[:From])
    end

    def agent_call_leg
      @agent_call_leg ||= Freshfone::Initiator::AgentCallLeg.new(
        params, current_account, current_call.freshfone_number, nil, telephony)
      @agent_call_leg.current_call ||= current_call
      @agent_call_leg
    end

    def transfer_missed?(call)
      call.missed_or_busy? && (call == current_call.descendants.last)
    end

    def disconnect_parent_call?(call)
      call.outgoing? && !child_missed?(call)
    end

    def child_missed?(call)
      call.has_children? && transfer_missed?(call.children.last)
    end
  end