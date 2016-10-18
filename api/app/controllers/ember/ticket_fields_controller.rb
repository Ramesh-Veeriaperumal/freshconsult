class Ember::TicketFieldsController < ::ApiTicketFieldsController
  
  PRELOAD_ASSOC = [
    :nested_ticket_fields, 
    :picklist_values => [
      :sub_picklist_values,
      :section => [:section_fields, :section_picklist_mappings => :picklist_value]
    ]
  ]

end
