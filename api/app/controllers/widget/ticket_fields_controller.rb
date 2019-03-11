module Widget
  class TicketFieldsController < Ember::TicketFieldsController
    include WidgetConcern
    skip_before_filter :check_privilege
    before_filter :validate_widget
    before_filter :set_widget_portal_as_current

    def index
      return render_request_error(:contact_form_not_enabled, 400, id: @widget_id) unless @help_widget.contact_form_enabled?
      
      super
    end

    private

      def scoper
        @current_portal.customer_editable_ticket_fields
      end
  end
end
