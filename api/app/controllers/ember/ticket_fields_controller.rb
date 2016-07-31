class Ember::TicketFieldsController < ApiApplicationController
  
  # skip_before_filter :check_privilege
  decorate_views
  
  include ControllerMethods::TicketFields
  
  private
  
  def resource
    # Hack to avoid adding additional entries at privileges.rb
    :api_ticket_field
  end
    
  
end