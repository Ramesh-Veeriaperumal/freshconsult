class Helpdesk::SectionPicklistValueMapping < ActiveRecord::Base
  
  include MemcacheKeys
  include MemcacheCleaner

  DELETE_CACHE_KEYS =[TICKET_FIELDS_FULL]

  self.primary_key = :id  
  attr_protected  :account_id
  
  belongs_to_account
  belongs_to :section, :class_name => "Helpdesk::Section"
  belongs_to :picklist_value, :class_name => "Helpdesk::PicklistValue"

  validates_uniqueness_of :picklist_value_id, :scope => :account_id

end
