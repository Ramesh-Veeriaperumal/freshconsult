class Helpdesk::SectionField < ActiveRecord::Base

  include Helpdesk::Ticketfields::Publisher
  include Concerns::ActsAsListPositionUpdate

  clear_memcache [ACCOUNT_SECTION_FIELD_PARENT_FIELD_MAPPING, ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING, TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT, ACCOUNT_SECTION_FIELDS]

  self.primary_key = :id
  self.table_name = "helpdesk_section_fields"

  COLUMN_NAMES_FOR_OPTAR = %i[id account_id section_id ticket_field_id parent_ticket_field_id position options created_at updated_at].freeze

  serialize :options
  
  attr_protected :account_id

  belongs_to_account
  swindle :dynamic_section_fields, attrs: COLUMN_NAMES_FOR_OPTAR
  belongs_to :ticket_field, :class_name => "Helpdesk::TicketField", :include => [:picklist_values, :nested_ticket_fields]
  belongs_to :parent_ticket_field, class_name: "Helpdesk::TicketField"
  belongs_to :section, :class_name => "Helpdesk::Section"
  belongs_to :required_ticket_field, :class_name => 'Helpdesk::TicketField', :conditions => {:required_for_closure => true}, :include => [:picklist_values, :nested_ticket_fields], :foreign_key => :ticket_field_id

  ticket_field_publishable

  acts_as_list scope: [:account_id, :section_id]

  def condition_valid?
    Account.current.ticket_field_revamp_enabled?
  end
end
