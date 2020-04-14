class Helpdesk::Access < ActiveRecord::Base
  def create_user_accesses(user_ids)
    return if user_ids.blank?
    users = Account.current.users.where(id: user_ids).to_a
    users.each do |user|
      self.users << user
    end
  end
    
  def remove_user_accesses(user_ids)
    if user_ids.nil?
      Helpdesk::UserAccess.delete_all(:account_id => self.account_id, :access_id => self.id)
    else
      return if user_ids.blank?
      Helpdesk::UserAccess.delete_all(:user_id => user_ids, :account_id => self.account_id, :access_id => self.id)
    end
  end

  def update_user_accesses(new_user_ids)
    old_user_ids = self.users.map{|user| user.id.to_s }
    to_be_removed = old_user_ids - new_user_ids
    to_be_added = new_user_ids - old_user_ids
    remove_user_accesses(to_be_removed)
    create_user_accesses(to_be_added)
  end
end
