class Helpdesk::Ticket < ActiveRecord::Base

  scope :permissible, lambda { |user| 
    { 
      :conditions => agent_permission(user)
    } if user.agent? 
  }

  scope :assigned_tickets_permission, lambda { |user, ids| {
    :select     => "helpdesk_tickets.display_id",
    :conditions => ["responder_id=? and display_id in (?)", user.id, ids] }
  }

  scope :group_tickets_permission, lambda { |user, ids| {
    :select     => "distinct helpdesk_tickets.display_id",
    :joins      => "LEFT JOIN agent_groups on helpdesk_tickets.group_id = agent_groups.group_id and helpdesk_tickets.account_id = agent_groups.account_id",
    :conditions => ["(agent_groups.user_id=? or helpdesk_tickets.responder_id=?) and display_id in (?)", user.id, user.id, ids] }
  }

  class << self

    def agent_permission user
      case Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]
      when :assigned_tickets
        ["responder_id=?", user.id]
      when :group_tickets
        ["group_id in (?) OR responder_id=?", user.agent_groups.pluck(:group_id).insert(0,0), user.id]
      when :all_tickets
        []
      end
    end
    
  end

  # Used in custom_ticket_filter.rb
  def agent_permission_condition user
    case Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]
    when :all_tickets
      ""
    when :group_tickets
      " AND (group_id in (
                    #{user.agent_groups.pluck(:group_id).insert(0,0)}) OR responder_id= #{user.id}) "
    when :assigned_tickets
      " AND (responder_id= #{user.id}) "
    end
  end

  # Possible dead code
  def get_default_filter_permissible_conditions user
    case Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]
    when :all_tickets
      ""
    when :group_tickets
      " [{\"condition\": \"responder_id\", \"operator\": \"is_in\",  \"value\": \"#{user.id}\"},
         {\"condition\": \"group_id\", \"operator\": \"is_in\",
                                     \"value\": \"#{user.agent_groups.pluck(:group_id).insert(0,0)}\"}] "
    when :assigned_tickets
      "[{\"condition\": \"responder_id\", \"operator\": \"is_in\", \"value\": \"#{user.id}\"}]"
    end
  end

  def accessible_in_helpdesk?(user)
    user.privilege?(:manage_tickets) && (user.can_view_all_tickets? || restricted_agent_accessible?(user) || group_agent_accessible?(user))
  end

  def restricted_in_helpdesk?(user)
    agent_as_requester?(user.id) && !accessible_in_helpdesk?(user)
  end

  def group_agent_accessible?(user)
    user.group_ticket_permission && (responder_id == user.id || Account.current.agent_groups.where(:user_id => user.id, :group_id => group_id).present? )
  end

  def restricted_agent_accessible?(user)
    user.assigned_ticket_permission && responder_id == user.id
  end

end
