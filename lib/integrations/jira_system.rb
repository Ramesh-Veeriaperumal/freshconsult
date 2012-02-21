module Integrations::JiraSystem
	
	def self.included(base)
    	base.helper_method :get_jira_username, :get_jira_password
  	end
	
	def get_jira_username(installed_app)
	    #installed_app=get_app_details("jira")
	    installed_app[0].configs[:inputs]['username']
	 end

	def get_jira_password(installed_app)
	    #installed_app = get_app_details("jira")
	    encrypted_pwd = installed_app[0].configs[:inputs]['password']
	    Integrations::AppsUtil.get_decrypted_value(encrypted_pwd)
	end
 end