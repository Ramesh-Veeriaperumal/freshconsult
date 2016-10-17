module Ember
  class TimeEntriesController < ::TimeEntriesController
    decorate_views(decorate_objects: [:ticket_time_entries])

    def ticket_time_entries
      return if validate_filter_params
      @items = paginate_items(@ticket.time_sheets)
      render '/ember/time_entries/index'
    end

    def create
      update_running_timer params[cname][:user_id] if @timer_running
      assign_protected
      if @item.save
        render_201_with_location(template_name: '/ember/time_entries/show.json', location_url: 'time_entry_url')
      else
        render_custom_errors
      end
    end

    def update
      super
      render '/ember/time_entries/show.json.api'
    end

    def toggle_timer
      super
      render '/ember/time_entries/show.json.api'
    end

    private

      def decorator_options
        super(ticket: @ticket)
      end

      def convert_duration(time_spent)
        time_spent
        # Emptying method as we donot want conversion here. API is expected to deal directly in seconds here.
      end
  end
end
