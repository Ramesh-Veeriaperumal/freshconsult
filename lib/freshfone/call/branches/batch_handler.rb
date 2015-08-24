module Freshfone::Call::Branches::BatchHandler
  include Freshfone::CallsRedisMethods

  def handle_batch_calls
    if batch_call?
      conference_call? ? conference_batch_Calls : normal_batch_call
    else
      clear_batch_key(params[:CallSid]) if params[:batch_call]
    end
  end

  def normal_batch_call
    return (render :xml => call_initiator.connect_caller_to_agent(@available_agents)) 
  end

  def conference_batch_Calls
    return (render :xml => call_initiator.connect_caller_to_agent(@available_agents))
  end

  private
    def batch_call?
      missed_call? && params[:batch_call] && batch_agents_ids.present? && batch_agents_online.present?
    end
    
    def batch_agents_ids
      @batch_agents_ids ||= begin
        key = FRESHFONE_AGENTS_BATCH % { :account_id => current_account.id, :call_sid => params[:CallSid] }
        batch_agents_ids = get_key(key)
        remove_key(key)
        batch_agents_ids.blank? ? batch_agents_ids : JSON::parse(batch_agents_ids)
      end
    end

    def batch_agents_online 
      sort_order = current_number.round_robin? ?  "ASC" : "DESC"
      @available_agents = current_account.freshfone_users.agents_by_last_call_at(sort_order).find_all_by_id(batch_agents_ids)
    end

    def conference_call?
      current_account.features?(:freshfone_conference)
    end

end