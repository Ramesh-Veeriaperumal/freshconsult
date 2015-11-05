class Helpdesk::ExternalNote < ActiveRecord::Base
  	self.primary_key = :id
	belongs_to :note, :class_name => 'Helpdesk::Note'
	belongs_to :installed_application, :class_name => 'Integrations::InstalledApplication'
	belongs_to_account
	self.table_name =  "helpdesk_external_notes"
end
