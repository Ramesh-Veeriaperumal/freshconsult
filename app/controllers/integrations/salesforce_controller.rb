class Integrations::SalesforceController < ApplicationController
	include Integrations::SalesforceUtil
	def fields_metadata
		begin
			installed_app = Integrations::InstalledApplication.find(:first, :include=>:application, :conditions => {:applications => {:name => "salesforce"}, :account_id => current_account})
			configs_hash = installed_app.configs[:inputs]
			configs_hash['contact_fields'] = fetch_sf_contact_fields(params['oauth_token'], configs_hash['instance_url']) 
	    configs_hash['lead_fields'] = fetch_sf_lead_fields(params['oauth_token'], configs_hash['instance_url']) 
	    installed_app.configs[:inputs] = configs_hash
	    installed_app.save!	
	    render :json => {'contact_fields' => installed_app.configs[:inputs]['contact_fields'], 'lead_fields' => installed_app.configs[:inputs]['lead_fields']}
		rescue Exception => msg
		 	Rails.logger.error "Error fetching feilds metadata from Salesforce. \n#{msg.message}\n#{msg.backtrace.join("\n\t")}"
		 	render :json => {:error=> "#{msg}"}
		 end
	end
end
