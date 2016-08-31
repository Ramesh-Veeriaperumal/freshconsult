module Ember
  class TicketsController < TicketsController
    include ControllerMethods::BulkActionMethods

    def index
      super
      response.api_meta = { count: tickets_filter.count }
      # TODO-EMBERAPI Optimize the way we fetch the count
      render 'tickets/index'
    end

    def bulk_delete
      return unless validate_body_params(*ApiTicketConstants::BULK_ACTION_FIELDS)
      sanitize_bulk_action_params
      fetch_objects(ApiTicketConstants::BULK_DELETE_PRELOAD_OPTIONS)
      destroy
      render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
    end

    def bulk_spam
      return unless validate_body_params(*ApiTicketConstants::BULK_ACTION_FIELDS)
      sanitize_bulk_action_params
      fetch_objects(ApiTicketConstants::BULK_DELETE_PRELOAD_OPTIONS)
      spam
      render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
    end

    def bulk_execute_scenario
      return unless validate_body_params(*ApiTicketConstants::BULK_ACTION_FIELDS)
      sanitize_bulk_action_params
      return unless load_scenario
      fetch_objects
      Tickets::BulkScenario.perform_async(ticket_ids: @items.map(&:display_id), scenario_id: params[:scenario_id])
      if bulk_action_errors.any?
        render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
      else
        head 202
      end
    end

    def execute_scenario
      return unless load_scenario
      fetch_objects
      return head 404 unless @item
      @va_rule.trigger_actions(@item, api_current_user)
      @item.save # TODO: verify if it should be save_ticket or save
      @item.create_scenario_activity(@va_rule.name)
      head 204
    end

    private

      def validate_body_params(*args)
        params[cname].permit(*args)
        ticket_validation = TicketValidation.new(params, nil)
        return true if ticket_validation.valid?(action_name.to_sym)
        render_errors ticket_validation.errors, ticket_validation.error_options
        false
      end

      def sanitize_bulk_action_params
        prepare_array_fields ApiTicketConstants::BULK_ACTION_ARRAY_FIELDS.map(&:to_sym)
      end

      def load_scenario
        @va_rule ||= current_account.scn_automations.find_by_id(params[:scenario_id])
        return true if @va_rule.present? && @va_rule.visible_to_me? && @va_rule.check_user_privilege
        render_errors(scenario_id: :"is invalid")
        false
      end

      def fetch_objects(preload_options = [], items = scoper)
        id_list = params[:id] ? Array.wrap(params[:id]) : params[cname][:ids]
        @items = items.preload(preload_options).find_all_by_param(permissible_ticket_ids(id_list))
        @item = @items.first
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
        @failed_ids ||= @items_failed ? @items_failed.map(&:display_id) : []
      end

      wrap_parameters(*wrap_params)
  end
end
