require 'spec_helper'

describe Integrations::SugarcrmController do

	setup :activate_authlogic
	self.use_transactional_fixtures = false

before(:all) do
  
    @app_config_options = {"domain" => "http://sugartest.ngrok.com", "password" => "TSCgFXhk5a",
                             "username" => "admin", "encryptiontype" => "md5"
                          }
    @installed_app_config_options = { :inputs => { 'domain' => "http://sugartest.ngrok.com",
								      "username" => "admin",
                                      "password" => "d4abbf52fd2dcf20695741bf08a0a02c",
                                      "account_labels" => "Name:",
                                      "accounts" => ["name"],
                                      "contact_labels" => "Name:",
                                      "contacts" => ["email_and_name1"],
                                      "lead_labels" => "Name:",
                                      "leads" => ["full_name"]
                                    } }
  end

  before(:each) do
    log_in(@agent)
  end

  it "should show sugarcrm settings page on the enable button click" do
    get :settings, {:controller=>"integrations/sugarcrm", :action=>"settings",:app_name=>"sugarcrm"}
    response.should render_template("integrations/applications/sugarcrm/sugarcrm_settings")
  end

  it "On the passing valid credentials it should save values to the DB and show the sugarcrm_fields page" do
    post :settings_update, {:controller => "integrations/sugarcrm", :action =>"settings_update",
                            :app_name => "sugarcrm",
                            :configs => @app_config_options }
    installed_application = @account.installed_applications.with_name("sugarcrm").first
    installed_application[:configs][:inputs]["domain"].should eql "http://sugartest.ngrok.com"
    installed_application[:configs][:inputs]["password"].should eql "d4abbf52fd2dcf20695741bf08a0a02c"
    installed_application[:configs][:inputs]["username"].should eql "admin"
    #since the passed values are valid it should update the db and should take to the next crm_custom_fields page
    response.should render_template("integrations/applications/form/crm_custom_fields_form")
  end

  it "On the settings update it should show validation message for wrong user name or password" do
    @app_config_options["username"] = "admin1"
    post :settings_update, {:controller => "integrations/sugarcrm", :action =>"settings_update",
                            :app_name => "sugarcrm",
                            :configs => @app_config_options }
    flash[:error].should eql "Invalid Login"
  end

  it "On the fields page update the user selected values should be updated to DB and integration enabled message should be shown" do
    post :fields_update, {
					      :controller => "integrations/sugarcrm", :action => "fields_update",
                          :app_name => 'sugarcrm',
                          :account_labels => "Name:",
                          :accounts => ["name"],
                          :contact_labels => "Name:",
                          :contacts => ["email_and_name1"],
                          :lead_labels => "Name:",  
                          :leads => ["full_name"]
                        }
    flash[:notice].should eql "The integration has been enabled successfully!"
    response.status.should eql 302
  end

   it "should return true if session_id is present in DB when check_session_id is called" do
    post :check_session_id, {:controller => "integrations/sugarcrm", :action =>"check_session_id",
                            :app_name => "sugarcrm",
                            :configs => @app_config_options }
    JSON.parse(response.body)["status"].should eql true
  end

   it "should return true if new session_id is created and updated in DB when renew_session_id is called" do
    post :renew_session_id, {:controller => "integrations/sugarcrm", :action =>"renew_session_id",
                            :app_name => "sugarcrm",
                            :configs => @app_config_options }
    JSON.parse(response.body)["status"].should eql true
  end

    it "should show the sugarcrm fields page on clicking the integration edit button" do
   get :edit, {:controller => "integrations/sugarcrm", :action => "edit", :app_name => "sugarcrm"}
    response.should render_template("integrations/applications/form/crm_custom_fields_form")
  end

  it "should show the application_index page on clicking the integration edit button when the session_id is invalid" do
    installed_application = @account.installed_applications.with_name("sugarcrm").first
    installed_application["configs"][:inputs]["session_id"] = "Invalid0session0id"
    installed_application.save(:validate => false)
    get :edit, {:controller => "integrations/sugarcrm", :action => "edit", :app_name => "sugarcrm"}
    session[:flash][:error].should eql I18n.t(:'integrations.sugarcrm.form.error')
    response.should redirect_to(integrations_applications_path)
  end
end
