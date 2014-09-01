# encoding: utf-8
class UserEmail < ActiveRecord::Base

  include Users::Activator
  include ActionController::UrlWriter

  EMAIL_REGEX = /(\A[-A-Z0-9.'’_&%=+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,15})\z)/i

  belongs_to :user
  belongs_to_account
  validates_presence_of :email
  validates_format_of :email, :with => EMAIL_REGEX
  validates_uniqueness_of :email, :scope => [:account_id]
  before_create :set_token, :if => :check_multiple_email_feature
  before_validation :downcase_email
  before_update :drop_authorization, :if => [:email_changed?, :check_multiple_email_feature]
  before_update :save_model_changes
  after_commit_on_update :change_email_status, :send_agent_activation, :if => [:check_for_email_change?, :check_multiple_email_feature]
  after_commit_on_create :send_activation, :if => :check_multiple_email_feature
  before_destroy :drop_authorization, :check_active_with_emails, :if => :check_multiple_email_feature

  def self.find_email_using_perishable_token(token, age)
    return if token.blank?
    
    age = age.to_i
    conditions_sql = "perishable_token = ?"
    conditions_subs = [token]
    if age > 0
      conditions_sql += " and updated_at > ?"
      conditions_subs << age.seconds.ago
    end
    find(:first, :conditions => [conditions_sql, *conditions_subs])
  end

  def save_model_changes
    @ue_changes = self.changes.clone
  end

  def check_multiple_email_feature
    self.account.features?(:multiple_user_emails)
  end

  def check_for_email_change?
    @ue_changes.key?("email")
  end

  def downcase_email
    self.email = email.downcase if email
  end

  def mark_as_verified
    self.update_attribute(:verified, true) if !self.verified?
  end

  # def self.user_for_email(email, scoper=nil)
  #   user_email = (scoper || UserEmail).find_by_email(email)
  #   user_email ? user_email.user : nil
  # end

  def self.user_for_email(email)
    if !Account.current.features?(:multiple_user_emails)
      Account.current.all_users.find_by_email(email)
    else
      user_email = find_by_email(email)
      user_email ? user_email.user : nil
    end
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    super(:builder => xml,:root=>options[:root], :skip_instruct => true,:only => [:email, :verified, :primary_role]) 
  end

  def as_json(options = {})
    options[:only] = [:id, :email, :verified, :primary_role]
    super options
  end

  def change_email_status
    self.update_attribute(:verified, false) if self.verified?
    deliver_contact_activation_email
  end

  protected

    def drop_authorization
      self.user.authorizations.each do |auth|
        auth.destroy unless ["twitter", "facebook"].include?(auth.provider)
      end 
    end

    def check_active_with_emails
      self.user.toggle(:active) if (self.user.active? and self.user.verified_emails.blank?)
    end

  private

    def set_token(portal=nil)
      self.perishable_token = Authlogic::Random.friendly_token
    end

    def send_activation
      deliver_contact_activation_email if self.user.active?
    end

    def send_agent_activation
      user.deliver_activation_instructions!(account.main_portal,false) if user.agent?
    end
end
