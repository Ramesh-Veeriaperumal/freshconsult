module Freshfone::Call::Branches::Transfer
  include Freshfone::CallsRedisMethods

  def handle_transferred_call
    if call_transferred?
      current_call.update_call(params)
      dial_to_source_agent and return empty_twmil_without_render if should_call_back_to_agent?
      add_transfer_cost_job
      update_agent_presence(params[:source_agent])
      unpublish_live_call(params)
      return empty_twmil_without_render
    end
  end

  def update_agent_presence(agent)
    return if agent.blank?
    agent = current_account.users.find_by_id(agent)
    update_freshfone_presence(agent, Freshfone::User::PRESENCE[:online])
    publish_freshfone_presence(agent)
    publish_success_of_call_transfer(agent, is_successful_transfer?)
  end

  def add_transfer_cost_job
    add_cost_job if transfer_complete?
  end

  private
    def call_transferred?
      @transfer_key = FRESHFONE_TRANSFER_LOG % { :account_id => current_account.id, 
                       :call_sid => (params[:ParentCallSid] || params[:CallSid]) }
      @transferred_calls ||= get_key(@transfer_key)
      @transferred_calls.present? || params[:call_back].present? 
      # call_back param used while source agent reject the transfered call
    end

    def dial_to_source_agent
      params.merge!({:outgoing => params[:outgoing].to_bool})
      update_transfer_log(params[:source_agent])
      render :xml => call_initiator.make_transfer_to_agent(params[:source_agent], true)
    end

    def should_call_back_to_agent?
      !( params[:CallStatus] == 'completed' || 
         params[:DialCallStatus] == 'completed'  || 
         params[:call_back].to_bool )
    end

    def transfer_complete?
      transferred_calls = JSON.parse(@transferred_calls)
      called_agent_id = current_call.user_id.to_s
      if transferred_calls.last == called_agent_id
        remove_key @transfer_key
        return true
      end
    end

    def is_successful_transfer?
     params[:DialCallStatus] == "in-progress"
    end

end