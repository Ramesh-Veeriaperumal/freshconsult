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
  
  before_save :restrict_domain, :if => :email_changed?
  
  # Make the verified as false if the email is changed
  before_update :change_email_status, :if => [:email_changed?]
  # Set new perishable token for activation after email is changed
  before_update :set_token, :if => [:email_changed?]
  before_update :save_model_changes

  before_create :set_token, :set_verified
  # after_commit :send_activation_on_create, on: :create

  # Drop all authorizations, if the email is changed
  after_update :drop_authorization, :if => [:email_changed?]
  after_commit :send_activation_on_update, on: :update, if: :email_updated?
  after_update :verify_account, :if => [:verified_changed?]

  before_destroy :drop_authorization
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher 

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

  def self.user_for_email(email, account = Account.current)
    user_email = where(email: email).first
    user_email ? user_email.user : nil
  end

  def self.existing_emails_for_emails(emails, account = Account.current)
    self.where(:email => emails).pluck(:email)
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

  def esv2_fields_updated?
    email_updated?
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
      self.verified = user.active if self.verified.nil?
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

    def email_updated?
      @ue_changes.key?("email")
    end

    def downcase_email
      self.email = email.downcase if email
    end

    def change_email_status
      self.verified = false
      true
    end

    def verify_account
      self.account.verify_account_with_email  if (!self.account.verified? && self.verified == true && self.user.privilege?(:admin_tasks))
    end
end
