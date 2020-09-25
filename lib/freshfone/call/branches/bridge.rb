module Freshfone::Call::Branches::Bridge

  def update_mobile_user_presence
    if answered_on_mobile?
      agent = current_account.users.find_by_id(params[:agent] || params[:agent_id])
      update_freshfone_presence(agent, Freshfone::User::PRESENCE[:online])
    end
  end

  private
    def answered_on_mobile?
      call_forwarded? and params[:direct_dial_number].blank?
    end
end