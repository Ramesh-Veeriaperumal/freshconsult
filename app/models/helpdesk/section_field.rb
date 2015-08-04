class Helpdesk::SectionField < ActiveRecord::Base

  self.primary_key = :id
  self.table_name = "helpdesk_section_fields"

  serialize :options
  
  attr_protected :account_id

  belongs_to_account
  belongs_to :ticket_field
  belongs_to :section

  validates_presence_of :ticket_field_id
end
