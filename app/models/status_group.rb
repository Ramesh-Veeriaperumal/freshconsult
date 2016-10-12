class StatusGroup < ActiveRecord::Base
  self.primary_key = :id
  
  belongs_to_account
  belongs_to :status, :class_name =>'Helpdesk::TicketStatus', :foreign_key => :status_id
  belongs_to :group

  after_commit :nullify_internal_group, on: :destroy
  after_commit :clear_account_status_groups_cache

  def nullify_internal_group
    return unless Account.current.features?(:shared_ownership) and Account.current.groups.exists?(group_id)

    reason        = self.status.deleted ? {:remove_status => [self.status.name]} :
      {:remove_group => [self.group.name, self.status.name]}
    message_hash  = {:internal_group_id => self.group_id, :status_id => self.status.status_id, :reason => reason}

    Helpdesk::ResetInternalGroup.perform_async(message_hash)
  end

  def clear_account_status_groups_cache
    Account.current.clear_account_status_groups_cache
  end

end
