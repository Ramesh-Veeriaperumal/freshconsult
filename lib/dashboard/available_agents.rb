class Dashboard::AvailableAgents < Dashboard

  def initialize
  end

  def fetch_records
    group_ids = User.current.accessible_roundrobin_groups.pluck(:id)
    return 0 if group_ids.blank?
    user_ids = Account.current.agent_groups.where(:group_id => group_ids).pluck(:user_id).uniq
    user_ids.present? ? Account.current.available_agents.where(:user_id => user_ids).count :  0
  end

end