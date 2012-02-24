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

  def jira_authenticity(params)
  	installed_app = Integrations::InstalledApplication.find(:all, :joins=>:application, 
                  :conditions => {:applications => {:name => "jira"}, :account_id => current_account})
  	username = get_jira_username(installed_app)
    password = get_jira_password(installed_app)
    params['domain'] = params[:configs]['domain']
    jiraObj = Integrations::JiraIssue.new(username, password, nil, params)
    jiraObj.jira_serverinfo
  end

 end