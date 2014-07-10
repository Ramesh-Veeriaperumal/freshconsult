class Helpdesk::ExternalNote < ActiveRecord::Base
	belongs_to :note, :class_name => 'Helpdesk::Note'
	belongs_to :installed_application, :class_name => 'Integrations::InstalledApplication'
	belongs_to :account
	set_table_name "helpdesk_external_notes"
end
