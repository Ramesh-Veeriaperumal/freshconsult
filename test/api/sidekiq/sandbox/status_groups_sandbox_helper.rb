module StatusGroupsSandboxHelper
  MODEL_NAME = Account.reflections["status_groups".to_sym].klass.new.class.name
  ACTIONS = ['delete', 'create']

  def status_groups_data(account)
    all_status_groups_data = []
    ACTIONS.each do |action|
      all_status_groups_data << send("#{action}_status_groups_data", account)
    end
    all_status_groups_data.flatten
  end

  def create_status_groups_data(account)
    status_groups_data = []
    if account.ticket_statuses.visible.present? && account.groups.present?
      status_group = StatusGroup.create({group_id: account.groups.first.id, status_id: account.ticket_statuses.visible.first.id})
      status_group.save
      status_groups_data = [status_group.attributes.merge("model" => MODEL_NAME, "action" => "added")]
      return status_groups_data
    else
      return []
    end
  end

  def delete_status_groups_data(account)
    status_group = account.status_groups.first
    return [] unless status_group
    status_group.destroy
    [status_group.attributes.merge("model" => MODEL_NAME, "action" => "deleted")]
  end
end
