class Helpdesk::PicklistValue < ActiveRecord::Base
  
  set_table_name "helpdesk_picklist_values"
  validates_presence_of :value
  validates_uniqueness_of :value, :scope => [:pickable_id, :pickable_type]
  
  belongs_to :pickable, :polymorphic => true
  
  acts_as_list
  
  # scope_condition for acts_as_list
  def scope_condition
    "pickable_id = #{pickable_id} AND #{connection.quote_column_name("pickable_type")} = 
    '#{pickable_type}'"
  end
end
