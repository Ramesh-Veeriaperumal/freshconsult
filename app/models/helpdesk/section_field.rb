class Helpdesk::SectionField < ActiveRecord::Base

  include MemcacheKeys

  self.primary_key = :id
  self.table_name = "helpdesk_section_fields"

  serialize :options
  
  attr_protected :account_id

  belongs_to_account
  belongs_to :ticket_field, :class_name => "Helpdesk::TicketField", :include => [:picklist_values, :nested_ticket_fields]
  belongs_to :parent_ticket_field, class_name: "Helpdesk::TicketField"
  belongs_to :section, :class_name => "Helpdesk::Section"
  belongs_to :required_ticket_field, :class_name => 'Helpdesk::TicketField', :conditions => {:required_for_closure => true}, :include => [:picklist_values, :nested_ticket_fields], :foreign_key => :ticket_field_id
  
  validates_presence_of :ticket_field_id

  after_commit :clear_cache

  def clear_cache
    acc_id_hash = { account_id: self.account_id }
    MemcacheKeys.delete_from_cache ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING % acc_id_hash
    MemcacheKeys.delete_from_cache TICKET_FIELDS_FULL % acc_id_hash
  end
end
