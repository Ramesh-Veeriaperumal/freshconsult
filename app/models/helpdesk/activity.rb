class Helpdesk::Activity < ActiveRecord::Base
  set_table_name "helpdesk_activities"

  belongs_to :notable, :polymorphic => true
  
  attr_protected :notable_id
  
  validates_presence_of :description, :notable_id

end
