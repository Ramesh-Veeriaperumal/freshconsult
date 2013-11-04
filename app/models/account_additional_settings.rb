class AccountAdditionalSettings < ActiveRecord::Base

  set_table_name "account_additional_settings" 
  belongs_to :account
  serialize :supported_languages
  validates_length_of :email_cmds_delimeter, :minimum => 3, :message => I18n.t('email_command_delimeter_length_error_msg')
  after_update :handle_email_notification_outdate, :if => :had_supported_languages?

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

end
