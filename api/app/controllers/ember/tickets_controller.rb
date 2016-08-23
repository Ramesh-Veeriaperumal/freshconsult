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
      return unless validate_bulk_action_params
      sanitize_bulk_action_params
      fetch_objects
      destroy
      render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
    end

    def bulk_spam
      return unless validate_bulk_action_params
      sanitize_bulk_action_params
      fetch_objects
      spam
      render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
    end

    private

      def validate_bulk_action_params
        params[cname].permit(*ApiTicketConstants::BULK_ACTION_FIELDS)
        ticket_validation = TicketValidation.new(params[cname], nil)
        return true if ticket_validation.valid?(action_name.to_sym)

        render_errors ticket_validation.errors, ticket_validation.error_options
        false
      end

      def sanitize_bulk_action_params
        prepare_array_fields ApiTicketConstants::BULK_ACTION_ARRAY_FIELDS.map(&:to_sym)
      end

      def fetch_objects(items = scoper)
        id_list = params[cname][:ids] || Array.wrap(params[cname][:id])
        @items = items.preload(ApiTicketConstants::BULK_DELETE_PRELOAD_OPTIONS).find_all_by_param(permissible_ticket_ids(id_list))
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
        @failed_ids ||= @items_failed.map(&:display_id)
      end

      wrap_parameters(*wrap_params)
  end
end
