module Widget
  class TicketFieldsController < Ember::TicketFieldsController
    include WidgetConcern
    skip_before_filter :check_privilege
    before_filter :validate_widget
    before_filter :set_widget_portal_as_current

    private
      def scoper
        @current_portal.customer_editable_ticket_fields
      end
  end
end
