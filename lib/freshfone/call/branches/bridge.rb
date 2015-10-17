module Freshfone::Call::Branches::Bridge
  include Freshfone::Queue

  def check_for_bridged_calls
    if answered_on_mobile?
      agent = current_account.users.find_by_id(params[:agent] || params[:agent_id]) 
      update_freshfone_presence(agent, Freshfone::User::PRESENCE[:online])
      bridge_queued_call(params[:agent] || params[:agent_id]) #if this is faster, replace with add_to_call_queue_worker
    end
  end

  private
    def answered_on_mobile?
      call_forwarded? and params[:direct_dial_number].blank?
    end
end