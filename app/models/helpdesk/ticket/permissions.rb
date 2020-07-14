class Helpdesk::Ticket < ActiveRecord::Base

  scope :permissible, lambda { |user| permissible_query_hash(user) }
  scope :assigned_tickets_permission, lambda { |user, ids| assigned_tickets_query_hash(user, ids) }
  scope :group_tickets_permission, lambda { |user, ids| group_tickets_query_hash(user, ids) }

  class << self

    def permissible_query_hash(user)
      if user.agent?
        query_hash = {:conditions => permissible_condition(user)}
        query_hash
      end
    end

    def permissible_condition user
      if user.assigned_tickets_permission?
        agent_condition user
      elsif user.group_tickets_permission?
        group_condition user
      elsif user.all_tickets_permission?
        []
      end
    end

    def agent_condition user
      if Account.current.shared_ownership_enabled?
        ["(responder_id = ? OR internal_agent_id = ?)", user.id, user.id]
      else
        ["responder_id = ?", user.id]
      end
    end

    def group_condition user
      group_ids = user.access_all_agent_groups ? user.all_associated_group_ids : user.associated_group_ids
      if Account.current.shared_ownership_enabled?
        ["(group_id IN (?) OR responder_id = ? OR internal_group_id IN (?) OR internal_agent_id = ?)", group_ids, user.id, group_ids, user.id]
      else
        ["(group_id IN (?) OR responder_id = ?)", group_ids, user.id]
      end
    end

    def group_tickets_query_hash(user, ids)
      query_hash = {:select => "#{Helpdesk::Ticket.table_name}.display_id"}

      query_hash[:conditions] = group_condition(user)
      query_hash[:conditions][0] += " AND display_id IN (?)"
      query_hash[:conditions] << ids

      query_hash
    end

    def assigned_tickets_query_hash(user, ids)
      query_hash = {:select => "#{Helpdesk::Ticket.table_name}.display_id"}

      query_hash[:conditions] = agent_condition(user)
      query_hash[:conditions][0] += " AND display_id IN (?)"
      query_hash[:conditions] << ids

      query_hash
    end

  end

  def accessible_in_helpdesk?(user)
    user.privilege?(:manage_tickets) && (user.can_view_all_tickets? || restricted_agent_accessible?(user) || group_agent_accessible?(user))
  end

  def restricted_in_helpdesk?(user)
    agent_as_requester?(user.id) && !accessible_in_helpdesk?(user)
  end

  def group_agent_accessible?(user)
    user.group_ticket_permission && (user.ticket_agent?(self) || (user.access_all_agent_groups ? user.read_or_write_group_ticket?(self) : user.group_ticket?(self)))
  end

  def restricted_agent_accessible?(user)
    user.assigned_ticket_permission && user.ticket_agent?(self)
  end
end
