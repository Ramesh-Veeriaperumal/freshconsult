class Integrations::CrmCompany < ActiveRecord::Base

  belongs_to_account
  
  # belongs_to :installed_application, :class_name => 'Integrations::InstalledApplication'

  attr_accessible :installed_application_id, :local_integratable_id, :remote_integratable_id

  named_scope :with_name, lambda { |comp_name| {:joins=>"INNER JOIN customers ON customers.id=crm_companies.local_integratable_id", :conditions=>["customers.name = ?", comp_name]}}
  
end