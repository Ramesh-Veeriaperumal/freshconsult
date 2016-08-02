class Ember::TicketFieldsController < ApiApplicationController
  
  # skip_before_filter :check_privilege
  decorate_views
  include ControllerMethods::TicketFields

  PRELOAD_ASSOC = [
    :nested_ticket_fields, 
    :picklist_values => [
      :sub_picklist_values,
      :section => [:section_fields, :section_picklist_mappings => :picklist_value]
    ]
  ]
  
  private
  
  def resource
    # Hack to avoid adding additional entries at privileges.rb
    :api_ticket_field
  end
  
end