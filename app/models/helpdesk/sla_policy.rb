class Helpdesk::SlaPolicy < ActiveRecord::Base
  
  set_table_name "helpdesk_sla_policies"
  
  belongs_to :account
  
  has_many :sla_details , :class_name => "Helpdesk::SlaDetail", :foreign_key => "sla_policy_id"
  
  accepts_nested_attributes_for :sla_details
  
end
