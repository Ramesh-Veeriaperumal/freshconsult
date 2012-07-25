class AccountAdditionalSettings < ActiveRecord::Base

  set_table_name "account_additional_settings" 

  belongs_to :account
  
  validates_length_of :email_cmds_delimeter, :minimum => 3, :message => I18n.t('email_command_delimeter_length_error_msg')

end
