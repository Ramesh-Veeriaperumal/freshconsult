class Helpdesk::SectionPicklistValueMapping < ActiveRecord::Base

  include Helpdesk::Ticketfields::Publisher
  
  clear_memcache [TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT]

  self.primary_key = :id
  attr_protected  :account_id
  
  belongs_to_account
  belongs_to :section, :class_name => "Helpdesk::Section"
  belongs_to :picklist_value, :class_name => "Helpdesk::PicklistValue"

  validates_uniqueness_of :picklist_value_id, :scope => :account_id

  ticket_field_publishable

  def ticket_field
    picklist_value.pickable
  end
  
end
