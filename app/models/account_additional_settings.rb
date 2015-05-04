class AccountAdditionalSettings < ActiveRecord::Base

  self.table_name =  "account_additional_settings" 
  self.primary_key = :id
  
  include AccountAdditionalSettings::AdditionalSettings

  belongs_to :account
  serialize :supported_languages
  validates_length_of :email_cmds_delimeter, :minimum => 3, :message => I18n.t('email_command_delimeter_length_error_msg')
  after_update :handle_email_notification_outdate, :if => :had_supported_languages?
  after_initialize :set_default_rlimit
  after_commit :clear_cache
  serialize :additional_settings, Hash
  serialize :resource_rlimit_conf, Hash
  validate :validate_bcc_emails

  def handle_email_notification_outdate
    if supported_languages_changed? 
    	removed = supported_languages_was - supported_languages
    	added = supported_languages - supported_languages_was

    	removed.each do |l|
    		DynamicNotificationTemplate.deactivate!(l) 
    	end	

    	added.each do |l|
    		DynamicNotificationTemplate.activate!(l)
    	end	
    end	
  end 

  def had_supported_languages?
    !supported_languages_was.nil?
  end 

  def validate_bcc_emails
    (bcc_email || "").split(",").each do |email|
      errors.add(:base,"Invalid email: #{email}") unless email =~ AccountConstants::EMAIL_SCANNER
    end
  end

  private

  def clear_cache
    self.account.clear_account_additional_settings_from_cache
  end

  def set_default_rlimit
    self.resource_rlimit_conf = self.resource_rlimit_conf.presence || DEFAULT_RLIMIT
  end

end
