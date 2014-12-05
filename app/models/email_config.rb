class EmailConfig < ActiveRecord::Base

  belongs_to :account
  belongs_to :product
  belongs_to :group, :foreign_key =>'group_id' #?!?!?! Not a literal belonging in true ER sense.

  attr_protected :account_id, :active
  
  has_one :imap_mailbox, :dependent => :destroy, :conditions => { :enabled => true }
  has_one :smtp_mailbox, :dependent => :destroy, :conditions => { :enabled => true }

  accepts_nested_attributes_for :imap_mailbox, :allow_destroy => true
  accepts_nested_attributes_for :smtp_mailbox, :allow_destroy => true

  validates_presence_of :to_email, :reply_email
  validates_uniqueness_of :reply_email, :scope => :account_id
  validates_uniqueness_of :activator_token, :allow_nil => true
  validates_format_of :reply_email, :with => ParserUtil::VALID_EMAIL_REGEX, :message => I18n.t('activerecord.errors.messages.invalid')
  validates_format_of :to_email, :with => ParserUtil::VALID_EMAIL_REGEX, :message => I18n.t('activerecord.errors.messages.invalid')
  
  xss_sanitize  :only => [:to_email,:reply_email], :plain_sanitizer => [:to_email,:reply_email]
  
  def active?
    active
  end
  
  def friendly_email
    active? ? "#{name} <#{reply_email}>" : "support@#{account.full_domain}"
  end
  
  def friendly_email_personalize(user_name)
    user_name = user_name ? user_name : name
    active? ? "#{user_name} <#{reply_email}>" : "support@#{account.full_domain}"
  end

  def set_activator_token
    (self.active = true) and return if reply_email.downcase.ends_with?("@#{account.full_domain.downcase}")
    
    self.active = false
    self.activator_token = Digest::MD5.hexdigest(Helpdesk::SECRET_1 + reply_email + Time.now.to_f.to_s).downcase
  end
  
  def reset_activator_token
    old_config = EmailConfig.find id
    set_activator_token unless old_config.reply_email == reply_email
  end
end