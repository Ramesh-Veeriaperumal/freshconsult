class ApiTicketFieldsController < ApiApplicationController
  decorate_views
  include ControllerMethods::TicketFields
end
