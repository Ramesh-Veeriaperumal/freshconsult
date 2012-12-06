class Monitorship < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  belongs_to_account
  validates_uniqueness_of :user_id, :scope => :topic_id
  validate :user_has_email
  
  

  named_scope :active_monitors, :conditions => { :active => true }

  before_create :set_account_id

  protected

  def user_has_email
  	unless user.has_email?
  	  errors.add(:user_id,"Not a valid user")
  	end
  end

  private
    def set_account_id
      self.account_id = user.account_id
    end
  
	
end
