module IntegrationsHelper

	def create_installed_applications(options= {})
		application_id = Integrations::Application.find_by_name(options[:application_name]).id
		installed_application = FactoryGirl.build(:installed_application, :configs => options[:configs],
		     								:account_id => options[:account_id],
		                  	:application_id => application_id)
		installed_application.save
		installed_application
	end
	
	def create_user_credentials(options = {})
		inst_app = create_installed_applications(options)
		user_credentials = FactoryGirl.build(:integration_user_credential, :installed_application_id => inst_app.id,
	     								:user_id => options[:user_id], :auth_info => options[:auth_info],
	                  	:account_id => options[:account_id])
		user_credentials.save
		user_credentials
	end

	def create_application(options = {})
		application = FactoryGirl.build(:application, :name => options[:name],
	     								:display_name => options[:display_name],:listing_order => options[:listing_order],
	     								:options => options[:options],:account_id => options[:account_id],
	     								:application_type => options[:application_type])
		application.save
		application
	end

end

