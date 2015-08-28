module Freshfone::Conference::EndCallActions

  def complete_call
    begin
      return empty_twiml if current_call.blank?
      return complete_transfer_leg if transfered_call_end? || external_transfer_call?
      current_call.disconnect_customer if current_call.onhold?
      current_call.disconnect_agent
      current_call.update_call(params) if !params[:To].empty? || single_leg_outgoing? # Outgoing issue fix. Explanation in spreadsheet: F59
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
    call = call.parent if outgoing_transfer_missed?(call) #if child call is missed or busy, then the params are for the parent call in outgoing.
    call.update_call(params) 
    call.outgoing? ? call.parent.disconnect_agent : call.disconnect_agent
    empty_twiml
  end

  private

    def external_transfer_call?
      !current_call.is_root? && current_call.direct_dial_number.present? && current_call.incoming?
    end

    def transfered_call_end?
      current_call.completed? && current_call.has_children? && current_call.descendants.present?
    end

    def single_leg_outgoing?
      current_call.outgoing? && current_call.is_root? && current_call.descendants.blank?
    end

    def disconnect_ringing
      return telephony.disconnect_call(current_call.dial_call_sid) if (single_leg_outgoing? && current_call.dial_call_sid.present?) #customer call end
      disconnect_ringing_agents
    end

    def disconnect_ringing_agents
      return if current_call.meta.blank?
      current_call.meta.pinged_agents.each do |agent| 
        next if agent[:call_sid].blank? || !agent[:response].blank?
        telephony.disconnect_call(agent[:call_sid])
      end
    end

    def still_ringing?
      (current_call.incoming? && current_call.noanswer?) || single_leg_outgoing?
    end

    def outgoing_transfer_missed?(call)
      current_call.outgoing? && call.missed_or_busy? && (call == current_call.descendants.last)
    end

    def add_preview_cost_job
      cost_params = { :account_id => current_account.id,
        :call_sid => params[:CallSid],
        :billing_type => Freshfone::OtherCharge::ACTION_TYPE_HASH[:ivr_preview] }
      Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, cost_params)
    end
end