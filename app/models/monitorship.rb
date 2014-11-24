class Monitorship < ActiveRecord::Base

  belongs_to_account
  belongs_to :monitorable, :polymorphic => true
  belongs_to :user
  belongs_to :portal
  validates_presence_of :monitorable_type, :monitorable_id
  validates_uniqueness_of :user_id, :scope => [:monitorable_id, :monitorable_type, :account_id]
  validate :user_has_email

  named_scope :active_monitors, :conditions => { :active => true }
  named_scope :by_user, lambda { |user| { :conditions => ["user_id = ?", user.id ] } }

  ALLOWED_TYPES = [:forum, :topic]
  ACTIONS = [:follow, :unfollow, :is_following]

  before_create :set_account_id

  def sender_and_host
    if !portal_id? || ( portal_id? && portal.main_portal? )
      sender = user.account.default_friendly_email
      host = user.account.host
    else
      sender = portal.friendly_email
      host = portal.host
    end
    [sender,host]
  end

  def get_portal
    @get_portal ||= portal_id? ? portal : account.main_portal
  end

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
