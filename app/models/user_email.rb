# encoding: utf-8
class UserEmail < ActiveRecord::Base

  self.primary_key = :id
  include Users::Activator
  include Rails.application.routes.url_helpers
  include AccountConstants


  API_OPTIONS = {
    :only => [:id, :email, :verified, :primary_role]
  }

  belongs_to :user
  belongs_to_account
  delegate :update_es_index, :to => :user

  validates_presence_of :email
  validates_format_of :email, :with => EMAIL_VALIDATOR
  validates_uniqueness_of :email, :scope => [:account_id]

  before_validation :downcase_email
  # Make the verified as false if the email is changed
  before_update :change_email_status, :if => [:email_changed?, :multiple_email_feature]
  # Set new perishable token for activation after email is changed
  before_update :set_token, :if => [:email_changed?, :contact_merge_ui_feature]
  before_update :save_model_changes

  before_create :set_token, :set_verified
  # after_commit :send_activation_on_create, on: :create, :if => :multiple_email_feature  

  # Drop all authorizations, if the email is changed
  after_update :drop_authorization, :if => [:email_changed?, :multiple_email_feature]
  after_commit :send_activation_on_update, on: :update, :if => [:check_for_email_change?, :multiple_email_feature]

  before_destroy :drop_authorization, :if => :multiple_email_feature

  scope :primary, :conditions => {:primary_role => true}, :limit => 1


  def self.find_email_using_perishable_token(token, age=1.weeks)
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

  def self.user_for_email(email)
    if !Account.current.features_included?(:multiple_user_emails)
      Account.current.all_users.find_by_email(email)
    else
      user_email = find_by_email(email)
      user_email ? user_email.user : nil
    end
  end

  def reset_perishable_token
    set_token
    save
  end

  def mark_as_verified
    self.update_attribute(:verified, true) if !self.verified?
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    options.merge!(API_OPTIONS)
    super(:builder => xml,:root=>options[:root], :skip_instruct => true) 
  end

  def as_json(options = {})
    options.merge!(API_OPTIONS)
    super options
  end

  protected

    def drop_authorization
      user.drop_authorization
    end

  private

    def set_token(portal=nil)
      self.perishable_token = Authlogic::Random.friendly_token
    end

    def set_verified
      self.verified = user.active
      true
    end

    def send_activation
      deliver_contact_activation_email if self.user.active? and !primary_role
    end

    alias :send_activation_on_create :send_activation
    alias :send_activation_on_update :send_activation

    def save_model_changes
      @ue_changes = self.changes.clone
    end

    def multiple_email_feature
      self.account.features_included?(:multiple_user_emails)
    end

    def contact_merge_ui_feature
      self.account.features_included?(:contact_merge_ui)
    end

    def check_for_email_change?
      @ue_changes.key?("email")
    end

    def downcase_email
      self.email = email.downcase if email
    end

    def change_email_status
      self.verified = false
      true
    end
end
