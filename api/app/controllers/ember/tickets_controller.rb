module Ember
  class TicketsController < TicketsController
    include DeleteSpamConcern

    def index
      super
      response.api_meta = { count: tickets_filter.count }
      # TODO-EMBERAPI Optimize the way we fetch the count
      render 'tickets/index'
    end

    def bulk_execute_scenario
      bulk_action do
        return unless load_scenario
        Tickets::BulkScenario.perform_async(ticket_ids: @items.map(&:display_id), scenario_id: params[:scenario_id])
      end
    end

    def execute_scenario
      return unless load_scenario
      @va_rule.trigger_actions(@item, api_current_user)
      @item.save
      @item.create_scenario_activity(@va_rule.name)
      head 204
    end

    private

      def load_scenario
        @va_rule ||= current_account.scn_automations.find_by_id(params[:scenario_id])
        return true if @va_rule.present? && @va_rule.visible_to_me? && @va_rule.check_user_privilege
        render_errors(scenario_id: :"is invalid")
        false
      end

      def fetch_objects(items = scoper)
        @items = items.preload(preload_options).find_all_by_param(permissible_ticket_ids(params[cname][:ids]))
      end

      def preload_options
        if ApiTicketConstants::REQUIRE_PRELOAD.include?(action_name.to_sym)
          ApiTicketConstants::BULK_DELETE_PRELOAD_OPTIONS
        end
      end

      def permissible_ticket_ids(id_list)
        @permissible_ids ||= begin
          if api_current_user.can_view_all_tickets?
            id_list
          elsif api_current_user.group_ticket_permission
            tickets_with_group_permission(id_list)
          elsif api_current_user.assigned_ticket_permission
            tickets_with_assigned_permission(id_list)
          else
            []
          end
        end
      end

      def tickets_with_group_permission(ids)
        scoper.group_tickets_permission(api_current_user, ids).map(&:display_id)
      end

      def tickets_with_assigned_permission(ids)
        scoper.assigned_tickets_permission(api_current_user, ids).map(&:display_id)
      end

      def bulk_action_errors
        @bulk_action_errors ||=
          params[cname][:ids].inject({}) { |a, e| a.merge retrieve_error_code(e) }
      end

      def retrieve_error_code(id)
        if bulk_action_failed_items.include?(id)
          { id => :unable_to_perform }
        elsif !bulk_action_succeeded_items.include?(id)
          { id => :"is invalid" }
        else
          {}
        end
      end

      def bulk_action_succeeded_items
        @succeeded_ids ||= @items.map(&:display_id) - bulk_action_failed_items
      end

      def bulk_action_failed_items
        @failed_ids ||= (@items_failed || []).map(&:display_id)
      end

      def update?
        @update ||= current_action?('update') || current_action?('execute_scenario')
      end

      wrap_parameters(*wrap_params)
  end
end
