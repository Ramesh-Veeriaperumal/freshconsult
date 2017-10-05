class Ember::TicketFieldsController < ::ApiTicketFieldsController

  send_etags_along('TICKET_FIELD_LIST')

  around_filter :run_on_db, :only => :index
  skip_around_filter :run_on_slave

  PRELOAD_ASSOC = [
    :nested_ticket_fields,
    picklist_values: [
      sub_picklist_values: { sub_picklist_values: [:sub_picklist_values] },
      section: [:section_fields, section_picklist_mappings: :picklist_value]
    ]
  ].freeze

  # Whenever we change the Structure (add/modify/remove keys), we will have to modify the below constant
  CURRENT_VERSION = 'private-v2'.freeze
end
