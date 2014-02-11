class Monitorship < ActiveRecord::Base

  belongs_to_account
  belongs_to :monitorable, :polymorphic => true
  belongs_to :user
  validates_presence_of :monitorable_type, :monitorable_id
  validates_uniqueness_of :user_id, :scope => [:monitorable_id, :monitorable_type, :account_id]
  validate :user_has_email

  named_scope :active_monitors, :conditions => { :active => true }

  ALLOWED_TYPES = [:forum, :topic]
  ACTIONS = [:follow, :unfollow]

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
