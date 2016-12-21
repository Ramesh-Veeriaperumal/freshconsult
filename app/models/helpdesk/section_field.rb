class Helpdesk::SectionField < ActiveRecord::Base

  include MemcacheKeys

  self.primary_key = :id
  self.table_name = "helpdesk_section_fields"

  serialize :options
  
  attr_protected :account_id

  belongs_to_account
  belongs_to :ticket_field, :class_name => "Helpdesk::TicketField"
  belongs_to :parent_ticket_field, class_name: "Helpdesk::TicketField"
  belongs_to :section, :class_name => "Helpdesk::Section"

  validates_presence_of :ticket_field_id

  after_commit :clear_cache

  def clear_cache
    key = ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING % { account_id: self.account_id }
    MemcacheKeys.delete_from_cache key
  end
end
