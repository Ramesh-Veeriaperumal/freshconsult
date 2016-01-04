class EmailConfig < ActiveRecord::Base
  self.primary_key = :id

  belongs_to_account
  include AccountConstants
  include Redis::RedisKeys
  include Redis::OthersRedis

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
  validates_format_of :reply_email, :with => AccountConstants::AUTHLOGIC_EMAIL_REGEX, 
                                    :message => I18n.t('activerecord.errors.messages.invalid')
  validates_format_of :to_email, :with => AccountConstants::AUTHLOGIC_EMAIL_REGEX, 
                                 :message => I18n.t('activerecord.errors.messages.invalid')
  validate :blacklisted_domain?
  
  xss_sanitize  :only => [:to_email,:reply_email], :plain_sanitizer => [:to_email,:reply_email]
  
  def active?
    active
  end
  
  def friendly_email
    if active?
      "#{format_name(name)} <#{reply_email}>"
    elsif primary_role?
      account.default_friendly_email
    else
      product.try(:primary_email_config) ? product.primary_email_config.friendly_email : 
                                           account.default_friendly_email
    end
  end
  
  def friendly_email_personalize(user_name)
    user_name = user_name ? user_name : name
    if active?
      "#{format_name(user_name)} <#{reply_email}>"
    elsif primary_role?
      account.default_friendly_email_personalize(user_name)
    else
      product.try(:primary_email_config) ? product.primary_email_config.friendly_email_personalize(user_name) : 
                                           account.default_friendly_email_personalize(user_name)
    end
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

  protected
    def blacklisted_domain?
      domain = self.reply_email.split("@").last.strip
      self.errors.add(:base, I18n.t('email_configs.blacklisted_domain_message')) \
        if ismember?(EMAIL_CONFIG_BLACKLISTED_DOMAINS, domain)
    end

  private
    # Wrap name with double quotes if it has a special character and not already wrapped
    def format_name(name)
      (name =~ SPECIAL_CHARACTERS_REGEX and name !~ /".+"/) ? "\"#{name}\"" : name
    end      

end