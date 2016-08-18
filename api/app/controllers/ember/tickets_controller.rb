module Ember
  class TicketsController < TicketsController
    def index
      super
      response.api_meta = { count: tickets_filter.count }
      # TODO-EMBERAPI Optimize the way we fetch the count
      render 'tickets/index'
    end

    def bulk_delete
      return unless validate_deletion_params
      sanitize_deletion_params
      fetch_objects
      delete_tickets
    end

    private

      def validate_deletion_params
        params[cname].permit(*ApiTicketConstants::BULK_DELETE_FIELDS)
        ticket_validation = TicketValidation.new(params[cname], nil)
        return true if ticket_validation.valid?(:bulk_delete)

        render_errors ticket_validation.errors, ticket_validation.error_options
        false
      end

      def sanitize_deletion_params
        prepare_array_fields ApiTicketConstants::BULK_DELETE_ARRAY_FIELDS.map(&:to_sym)
      end

      def fetch_objects(items = scoper)
        @items = items.preload(ApiTicketConstants::BULK_DELETE_PRELOAD_OPTIONS).find_all_by_display_id(permissible_ticket_ids)
      end

      def permissible_ticket_ids
        @permissible_ids ||= begin
          if api_current_user.can_view_all_tickets?
            params[cname][:ids]
          else
            tickets_with_group_permission(params[cname][:ids]) | tickets_assigned(params[cname][:ids])
          end
        end
      end

      def tickets_with_group_permission(ids)
        api_current_user.group_ticket_permission ? scoper.group_tickets_permission(api_current_user, ids).map(&:display_id) : []
      end

      def tickets_assigned(ids)
        api_current_user.assigned_ticket_permission ? scoper.assigned_tickets_permission(api_current_user, ids).map(&:display_id) : []
      end

      def delete_tickets
        @tickets_not_deleted = []
        @items.each do |item|
          is_deleted = item.deleted
          item.deleted = true
          store_dirty_tags(item) # Storing tags whenever ticket is deleted. So that tag count is in sync with DB.
          @tickets_not_deleted << item.display_id unless !is_deleted && item.save
        end

        if bulk_delete_errors.any?
          render_partial_success(deleted_ticket_ids, bulk_delete_errors)
        else
          head 205
        end
      end

      def bulk_delete_errors
        @bulk_delete_errors ||=
          params[cname][:ids].inject({}) { |a, e| a.merge deletion_error(e) }
      end

      def invalid_ticket_ids
        @invalid_ids ||= params[cname][:ids] - @items.map(&:display_id)
      end

      def deleted_ticket_ids
        @deleted_ids ||= @items.map(&:display_id) - @tickets_not_deleted
      end

      def deletion_error(id)
        if invalid_ticket_ids.include?(id)
          { id => :"is invalid" }
        elsif @tickets_not_deleted.include?(id)
          { id => :unable_to_delete }
        else
          {}
        end
      end

      wrap_parameters(*wrap_params)
  end
end
