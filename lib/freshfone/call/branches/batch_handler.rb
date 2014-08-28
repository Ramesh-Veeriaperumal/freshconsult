module Freshfone::Call::Branches::BatchHandler
  include Freshfone::CallsRedisMethods

  def handle_batch_calls
    return (render :xml => call_initiator.connect_caller_to_agent(@available_agents)) if batch_call?
    clear_batch_key if params[:batch_call]
  end

  private
    def batch_call?
      missed_call? && params[:batch_call] && batch_agents_ids.present? && batch_agents_online.present?
    end
    
    def clear_batch_key
      key = FRESHFONE_AGENTS_BATCH % { :account_id => current_account.id, :call_sid => params[:CallSid] }
      remove_key(key)
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
      asc_desc = current_number.round_robin? ? "ASC" : "DESC" 
      @available_agents = current_account.freshfone_users.agents_online_ordered(asc_desc).find_all_by_id(batch_agents_ids)
    end


end