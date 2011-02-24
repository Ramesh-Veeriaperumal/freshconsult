class Helpdesk::Activity < ActiveRecord::Base
  set_table_name "helpdesk_activities"
  
  serialize :activity_data

  belongs_to :account
  belongs_to :user
  belongs_to :notable, :polymorphic => true
  
  attr_protected :notable_id
  
  validates_presence_of :description, :notable_id, :user_id
  
  before_create :set_short_descr
  
  named_scope :freshest, lambda { |account|
    { :conditions => ["account_id = ? ", account], 
      :order => "helpdesk_activities.created_at DESC"
    }
  }
  
  private
    def set_short_descr
      self.short_descr ||= description
    end

end
