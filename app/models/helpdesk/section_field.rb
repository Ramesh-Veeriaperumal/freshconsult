class Helpdesk::SectionField < ActiveRecord::Base

  include Helpdesk::Ticketfields::Publisher

  clear_memcache [ACCOUNT_SECTION_FIELD_PARENT_FIELD_MAPPING, ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING, TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT]

  self.primary_key = :id
  self.table_name = "helpdesk_section_fields"

  serialize :options
  
  attr_protected :account_id

  belongs_to_account
  swindle :dynamic_section_fields, attrs: %i[id account_id ticket_field_id parent_ticket_field_id section_id position options]
  belongs_to :ticket_field, :class_name => "Helpdesk::TicketField", :include => [:picklist_values, :nested_ticket_fields]
  belongs_to :parent_ticket_field, class_name: "Helpdesk::TicketField"
  belongs_to :section, :class_name => "Helpdesk::Section"
  belongs_to :required_ticket_field, :class_name => 'Helpdesk::TicketField', :conditions => {:required_for_closure => true}, :include => [:picklist_values, :nested_ticket_fields], :foreign_key => :ticket_field_id
  
  validates_presence_of :ticket_field_id

  ticket_field_publishable
  
end
