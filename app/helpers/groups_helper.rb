module GroupsHelper
  
  def global_access?
    current_user.privilege?(:admin_tasks)
  end

  def show_roundrobin_v2_notification?
    global_access? and current_account.features?(:round_robin) and !manage_availability_exists?
  end

  def manage_availability_exists?(account = current_account)
    account.roles.supervisor.first.privilege?(:manage_availability)
  end

end
