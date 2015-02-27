class Integrations::CrmContact < ActiveRecord::Base

  belongs_to_account
  
  # belongs_to :installed_application, :class_name => 'Integrations::InstalledApplication'

  attr_accessible :installed_application_id, :local_integratable_id, :remote_integratable_id
  
end