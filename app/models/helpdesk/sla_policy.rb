class Helpdesk::SlaPolicy < ActiveRecord::Base
  
  set_table_name "helpdesk_sla_policies"
  
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id
  
  belongs_to :account
  
  has_many :sla_details , :class_name => "Helpdesk::SlaDetail", :foreign_key => "sla_policy_id" , :dependent => :destroy 
  
  attr_accessible :name,:description,:is_default
  
  accepts_nested_attributes_for :sla_details
  
end
