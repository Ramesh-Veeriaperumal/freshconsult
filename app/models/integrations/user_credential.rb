class Integrations::UserCredential < ActiveRecord::Base
	include Integrations::AppsUtil
	belongs_to :installed_application, :class_name => 'Integrations::InstalledApplication'
	belongs_to :user
	belongs_to_account
	
	serialize :auth_info, Hash

	before_save :auth_config

	set_table_name "integrations_user_credentials"

	def self.add_or_update(installed_application, user_id, params={})
		
		user_credential = installed_application.user_credentials.find_by_user_id(user_id)
		unless user_credential
			user_credential = installed_application.user_credentials.build
			user_credential.user_id = user_id
		end
		user_credential.auth_info = params
		user_credential.account_id = installed_application.account_id
		user_credential.save!
	end

	def auth_config
		return if installed_application.application.options[:auth_config].blank?
		ac = installed_application.application.options[:auth_config]
		unless ac.blank?
			execute(ac[:clazz], ac[:method], self)
		end		
	end
	  
end
