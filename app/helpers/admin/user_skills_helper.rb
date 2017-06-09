module Admin::UserSkillsHelper

  def access_to_filtered_group?(group = @filtered_group)
    current_user.privilege?(:admin_tasks) || (current_user.privilege?(:manage_availability) && group.has_agent?(current_user))
  end

end
