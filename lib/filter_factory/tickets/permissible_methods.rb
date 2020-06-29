module FilterFactory::Tickets
  module PermissibleMethods
    private

      def permissible_conditions
        if User.current.can_view_all_tickets?
          {}
        elsif User.current.group_ticket_permission
          group_scoped_conditions
        else
          user_scoped_conditions
        end
      end

      def group_scoped_conditions
        group_ids = User.current.access_all_agent_groups ? User.current.all_associated_group_ids : User.current.associated_group_ids
        conditions = [group_condition(group_ids), user_condition]
        conditions += [internal_group_condition(group_ids), internal_agent_condition] if Account.current.shared_ownership_enabled?
        { or_conditions: [conditions] } # To accomodate due_by
      end

      def user_scoped_conditions
        conditions = [user_condition]
        conditions << internal_agent_condition if Account.current.shared_ownership_enabled?
        { or_conditions: [conditions] } # To accomodate due_by
      end

      def group_condition(group_ids)
        {
          condition: :group_id,
          operator: :is_in,
          value: group_ids
        }
      end

      def user_condition
        {
          condition: :responder_id,
          operator: :is_in,
          value: User.current.id
        }
      end

      def internal_group_condition(group_ids)
        {
          condition: :internal_group_id,
          operator: :is_in,
          value: group_ids
        }
      end

      def internal_agent_condition
        {
          condition: :internal_agent_id,
          operator: :is_in,
          value: User.current.id
        }
      end
  end
end
