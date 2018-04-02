module Archive
  module Tickets
    class ActivitiesController < Ember::Tickets::ActivitiesController
      private

        def feature_name
          :archive_tickets
        end

        def load_objects
          @collection = fetch_activities(pagination_params, @ticket)
          if @collection == false || @collection.error_message.present?
            render_base_error(:internal_error, 500)
            return
            # TODO-EMBERAPI Come up with better errors
          end
          query_hash = @collection.members.present? ? JSON.parse(@collection.members).symbolize_keys : {}
          @query_data_hash = parse_query_hash(query_hash, @ticket, true)
          @items = @collection.ticket_data
          @items_count = @collection.total_count
          add_field_mappings
        end

        def load_ticket
          @ticket = current_account.archive_tickets.find_by_display_id(params['id'])
          log_and_render_404 unless @ticket
        end
    end
  end
end
