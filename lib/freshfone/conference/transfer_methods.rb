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

  def telephony
    current_number ||= current_call.freshfone_number
    @telephony ||= Freshfone::Telephony.new(params, current_account, current_number)
  end
end