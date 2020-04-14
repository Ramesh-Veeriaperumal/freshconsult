class Helpdesk::Access < ActiveRecord::Base
  def create_group_accesses(group_ids)
    return if group_ids.blank?
    groups = Account.current.groups.where(id: group_ids).to_a
    groups.each do |group|
      self.groups << group
    end
  end

  def remove_group_accesses(group_ids)
    if group_ids.nil?
      Helpdesk::GroupAccess.delete_all(:account_id => self.account_id, :access_id => self.id)
    else
      return if group_ids.blank?
      Helpdesk::GroupAccess.delete_all(:group_id => group_ids, :account_id => self.account_id, :access_id => self.id)
    end
  end

  def update_group_accesses(new_group_ids)
    old_group_ids = self.groups.map{|group| group.id.to_s}
    to_be_removed = old_group_ids - new_group_ids
    to_be_added = new_group_ids - old_group_ids
    remove_group_accesses(to_be_removed)
    create_group_accesses(to_be_added)
  end
end