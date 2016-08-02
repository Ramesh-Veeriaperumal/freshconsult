class ApiTicketFieldsController < ApiApplicationController

  decorate_views
  include ControllerMethods::TicketFields

  PRELOAD_ASSOC = [ :nested_ticket_fields ]
end
