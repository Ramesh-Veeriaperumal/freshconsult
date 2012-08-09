class Monitorship < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  validates_uniqueness_of :user_id, :scope => :topic_id
  validate :user_has_email
  
  

  named_scope :active_monitors, :conditions => { :active => true }

  protected

  def user_has_email
  	unless user.has_email?
  	  errors.add(:user_id,"Not a valid user")
  	end
  end

	
end
