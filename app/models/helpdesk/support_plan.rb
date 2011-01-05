class Helpdesk::SupportPlan < ActiveRecord::Base
  set_table_name "helpdesk_support_plans"
  
  
  
  has_many :sla_details , :class_name => "Helpdesk::SlaDetail", :foreign_key => "support_plan_id"
  
  accepts_nested_attributes_for :sla_details
  
end
