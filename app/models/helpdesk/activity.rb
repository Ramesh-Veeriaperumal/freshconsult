class Helpdesk::Activity < ActiveRecord::Base
  set_table_name "helpdesk_activities"
  
  serialize :activity_data

  belongs_to :account
  belongs_to :user
  belongs_to :notable, :polymorphic => true
  
  attr_protected :notable_id
  
  validates_presence_of :description, :notable_id

end
