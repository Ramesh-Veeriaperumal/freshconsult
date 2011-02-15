class Monitorship < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  

  named_scope :active_monitors, :conditions => { :active => true }

	
end
