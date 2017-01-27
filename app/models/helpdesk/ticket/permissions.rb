class Helpdesk::Ticket < ActiveRecord::Base

  scope :permissible, lambda { |user| permissible_query_hash(user) }
  scope :assigned_tickets_permission, lambda { |user, ids| assigned_tickets_query_hash(user, ids) }
  scope :group_tickets_permission, lambda { |user, ids| group_tickets_query_hash(user, ids) }

  class << self

    def responder_id_with_table
      "#{Helpdesk::Ticket.table_name}.responder_id"
    end

    def internal_agent_id_with_table
      "#{Helpdesk::SchemaLessTicket.table_name}.#{Helpdesk::SchemaLessTicket.internal_agent_column}"
    end

    def group_id_with_table
      "#{Helpdesk::Ticket.table_name}.group_id"
    end

    def internal_group_id_with_table
      "#{Helpdesk::SchemaLessTicket.table_name}.#{Helpdesk::SchemaLessTicket.internal_group_column}"
    end

    def permissible_query_hash(user)
      if user.agent?
        query_hash = {:conditions => permissible_condition(user)}
        query_hash[:joins] = permissible_join(user)
        query_hash
      end
    end

    def permissible_join(user)
      " INNER JOIN helpdesk_schema_less_tickets on helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id AND helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id " if !user.all_tickets_permission? && Account.current.features?(:shared_ownership)
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
      if Account.current.features?(:shared_ownership)
        ["(#{responder_id_with_table} = ? OR #{internal_agent_id_with_table} = ?)", user.id, user.id]
      else
        ["#{responder_id_with_table} = ?", user.id]
      end
    end

    def group_condition user
      group_ids = user.associated_group_ids
      if Account.current.features?(:shared_ownership)
        ["(#{group_id_with_table} IN (?) OR #{responder_id_with_table} = ? OR #{internal_group_id_with_table} IN (?) OR #{internal_agent_id_with_table} = ?)", group_ids, user.id, group_ids, user.id]
      else
        ["(#{group_id_with_table} IN (?) OR #{responder_id_with_table} = ?)", group_ids, user.id]
      end
    end

    def group_tickets_query_hash(user, ids)
      query_hash = {:select => "#{Helpdesk::Ticket.table_name}.display_id"}

      query_hash[:conditions] = group_condition(user)
      query_hash[:conditions][0] += " AND display_id IN (?)"
      query_hash[:conditions] << ids

      query_hash[:joins] = permissible_join(user)
      query_hash
    end

    def assigned_tickets_query_hash(user, ids)
      query_hash = {:select => "#{Helpdesk::Ticket.table_name}.display_id"}

      query_hash[:conditions] = agent_condition(user)
      query_hash[:conditions][0] += " AND display_id IN (?)"
      query_hash[:conditions] << ids

      query_hash[:joins] = permissible_join(user)
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
    user.group_ticket_permission && (user.ticket_agent?(self) || user.group_ticket?(self) )
  end

  def restricted_agent_accessible?(user)
    user.assigned_ticket_permission && user.ticket_agent?(self)
  end

end
