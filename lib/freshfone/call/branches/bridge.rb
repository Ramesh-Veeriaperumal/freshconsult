module Freshfone::Call::Branches::Bridge
  include Freshfone::Queue

  def check_for_bridged_calls
    p "answered_on_mobile? => #{answered_on_mobile?}"
    if answered_on_mobile?
      p "will update the presence? => #{answered_on_mobile?}"
      agent = current_account.users.find_by_id(params[:agent]) 
      update_freshfone_presence(agent, Freshfone::User::PRESENCE[:online])
      bridge_queued_call(params[:agent])
    end
  end

  private
    def answered_on_mobile?
      call_forwarded? and params[:direct_dial_number].blank?
    end
end