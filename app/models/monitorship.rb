class Monitorship < ActiveRecord::Base
  self.primary_key = :id

  belongs_to_account
  belongs_to :monitorable, :polymorphic => true
  belongs_to :user
  belongs_to :portal
  validates_presence_of :monitorable_type, :monitorable_id
  validates_uniqueness_of :user_id, :scope => [:monitorable_id, :monitorable_type, :account_id]
  validate :user_has_email

  scope :active_monitors, :conditions => { :active => true }
  scope :by_user, lambda { |user| { :conditions => ["user_id = ?", user.id ] } }

  ALLOWED_TYPES = [:forum, :topic]
  ACTIONS = [:follow, :unfollow, :is_following, :followers]
  ADD_FOLLOWER_MAILERS_FOR = [:topic, :forum]

  before_create :set_account_id
  after_create :notify_new_follower
  after_update :notify_new_follower, :if => :active_changed?

  def sender_and_host
    if portal && !portal.main_portal?
      sender = portal.friendly_email
      host = portal.host
    else
      sender = user.account.default_friendly_email
      host = user.account.host
    end
    [sender,host]
  end

  def get_portal
    @get_portal ||= portal_id? ? portal : account.main_portal
  end

  def notify_new_follower
    return if mail_unnecessary?
    "#{monitorable.class.name}Mailer".constantize.send_later(:notify_new_follower,monitorable,User.current,portal,self)
  end

  protected

  def mail_unnecessary?
    [
      (User.current.blank? || User.current.id != user_id),
      self.active?,
      ADD_FOLLOWER_MAILERS_FOR.include?(monitorable.class.to_s.downcase.to_sym),
      self.user.privilege?(:view_forums)
    ].include?(false)
  end

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
