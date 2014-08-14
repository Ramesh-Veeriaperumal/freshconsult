module Freshfone::Call::EndCallActions
  include Freshfone::CallsRedisMethods
  include Freshfone::TicketActions

  def normal_end_call
    params[:agent] ||= called_agent_id
    current_call.update_call(params)
    unpublish_live_call(params)
    empty_twiml
  end

  def handle_forwarded_calls
    unpublish_live_call(params)
    current_call.update_call(params)
    empty_twiml
  ensure
    update_user_presence if params[:direct_dial_number].blank?
  end

  def clear_client_calls
    key = FRESHFONE_CLIENT_CALL % { :account_id => current_account.id }
    remove_from_set(key, params[:DialCallSid]) if params[:DialCallSid]
  end

  def reset_outgoing_count
    remove_device_from_outgoing(split_client_id(params[:From])) if current_call.outgoing?
  end

  def add_cost_job
    Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, cost_params) 
    Rails.logger.debug "FreshfoneJob for sid : #{params[:CallSid]} :: dsid : #{params[:DialCallSid]}"
  end

  def cost_params
    { :account_id => current_account.id, 
      :call_sid => params[:CallSid], 
      :dial_call_sid => params[:DialCallSid],
      :call => (current_call || {})[:id],
      :call_forwarded => call_forwarded?,
      :billing_type => preview? ? Freshfone::OtherCharge::ACTION_TYPE_HASH[:ivr_preview] : nil,
      :transfer => call_transferred?,
      :number_id => params[:number_id],
      :below_safe_threshold => params[:below_safe_threshold]
    }
  end

end