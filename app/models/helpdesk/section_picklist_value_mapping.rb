class Helpdesk::SectionPicklistValueMapping < ActiveRecord::Base
  include MemcacheKeys
  
  self.primary_key = :id  
  attr_protected  :account_id
  
  belongs_to_account
  belongs_to :section, :class_name => "Helpdesk::Section"
  belongs_to :picklist_value, :class_name => "Helpdesk::PicklistValue"

  validates_uniqueness_of :picklist_value_id, :scope => :account_id

  after_commit :clear_cache

  def clear_cache
    MemcacheKeys.delete_from_cache TICKET_FIELDS_FULL % { :account_id => self.account_id }
  end
end
