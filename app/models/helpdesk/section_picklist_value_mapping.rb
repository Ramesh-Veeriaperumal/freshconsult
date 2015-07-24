class Helpdesk::SectionPicklistValueMapping < ActiveRecord::Base
  
  self.primary_key = :id  
  attr_protected  :account_id
  
  belongs_to_account
  belongs_to :section
  belongs_to :picklist_value

  validates_uniqueness_of :picklist_value_id, :scope => :account_id
end
