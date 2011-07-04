class Monitorship < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  validates_uniqueness_of :user_id, :scope => :topic_id
  

  named_scope :active_monitors, :conditions => { :active => true }

	
end
