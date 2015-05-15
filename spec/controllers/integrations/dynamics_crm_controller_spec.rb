require 'spec_helper'

describe Integrations::DynamicsCrmController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    application = FactoryGirl.build(:application, :name => "dynamicscrm",
                                    :display_name => "integrations.dynamicscrm.label",
                                    :listing_order => 31,
                                    :options => {
                                      :direct_install => false
                                    },
                                    :account_id => 0,
                                    :application_type => "dynamicscrm")
    application.save(:validate => false)
    @app_config_options = {"domain" => "bala@freshpo5.onmicrosoft.com", "password" => "opmanager!@#4",
                             "instance_type" => "On-Demand", "organization_name" => "freshpo5",
                             "endpoint" => "https://freshpo5.api.crm.dynamics.com/XRMServices/2011/Organization.svc",
                             "email" => "bala@freshdesk.com", "lead_email" => "bala@freshdesk.com",
                             "account_email" => "bala@freshdesk.com", "contact_email" => "bala@freshdesk.com"
                          }
    @installed_app_config_options = { :inputs => { 'domain' => "bala@freshpo5.onmicrosoft.com",
                                      "instance_type" => "On-Demand",
                                      "organization_name" => "freshpo5",
                                      "endpoint" => "https://freshpo5.api.crm.dynamics.com/XRMServices/2011/Organization.svc",
                                      "account_email" => "bala@freshdesk.com",
                                      "contact_email" => "bala@freshdesk.com",
                                      "lead_email" => "bala@freshdesk.com",
                                      "password" => "mrrsqGi735LE+KoOnsZEqDjqyn1p0ummXmhn1oYxZZhOxwGU7cNz+7svyHXB\n7xHDf7HoQ7Z+8jX5sgAryyO7lKKyRJbs4BQbzhH8O4ifua8TReLGU5ICOjTS\nZ0j+lXS3cre8VVH/SamyU4t08FyAHc6BTMPBX5fFbnis+zVPbiiCOFqZY/CX\nEXCR202ue6gXBYgJVNgGuMYOQm6DvrPlBtIFsAFgUyoRWY6+iacRxlVsIPWk\n0mzs3WIw4ILJpyqucfripKC5vFZHaJkb2bpSSBX6jOhz3x0xKUz/CqVGHHD0\nHP4UNZB5xFPvlaIQuu6sMXN50u7/aDSVK5ddQC9cNg==\n",
                                      "account_labels" => "Job Title,Telephone,Mobile Phone",
                                      "accounts" => ["attributes.jobtitle", "attributes.telephone1", "attributes.mobilephone"],
                                      "contact_labels" => "Job Title,new_contactcustomfield,Telephone,Mobile Phone,Address,Owner",
                                      "contacts" => ["attributes.jobtitle", "attributes.new_contactcustomfield", "attributes.telephone1", "attributes.mobilephone", "attributes.address1_composite", "attributes.ownerid['Name']"],
                                      "lead_labels" => "Job Title,Telephone,Mobile Phone",
                                      "leads" => ["attributes.jobtitle", "attributes.telephone1", "attributes.mobilephone", "attributes.address1_composite", "attributes.ownerid['Name']"]
                                    } }
  end

  before(:each) do
    log_in(@agent)
  end

  it "should show dynamics settings page on the install button click" do
    get :settings, {:controller=>"integrations/dynamics_crm", :action=>"settings",:app_name=>"dynamicscrm"}
    response.should render_template("integrations/applications/dynamics_crm/dynamics_settings")
  end

  it "On the passing valid credentials and email id it should save values to the DB and show the dynamics_fields page" do
    post :settings_update, {:controller => "integrations/dynamics_crm", :action =>"settings_update",
                            :app_name => "dynamicscrm",
                            :configs => @app_config_options }
    installed_application = @account.installed_applications.with_name("dynamicscrm").first
    installed_application[:configs][:inputs]["domain"].should eql "bala@freshpo5.onmicrosoft.com"
    installed_application.configsdecrypt_password.should eql "opmanager!@#4"
    installed_application[:configs][:inputs]["lead_email"].should eql "bala@freshdesk.com"
    installed_application[:configs][:inputs]["contact_email"].should eql "bala@freshdesk.com"
    installed_application[:configs][:inputs]["account_email"].should eql "bala@freshdesk.com"
    #since the passed values are valid it should update the db and should take to the next dynamics_field page
    response.should render_template("integrations/applications/dynamics_crm/dynamics_fields")
  end

  it "On the settings update it should show validation message for wrong user name or password" do
    @app_config_options["domain"] = "bala1@freshpo5.onmicrosoft.com"
    post :settings_update, {:controller => "integrations/dynamics_crm", :action =>"settings_update",
                            :app_name => "dynamicscrm",
                            :configs => @app_config_options }
    flash[:error].should eql "Oops, something went wrong! Please verify if you have entered correct values."
  end

  it "On the settings update it should show validation message for a wrong contact/lead/account email" do
    @app_config_options["domain"] = "bala@freshpo5.onmicrosoft.com"
    @app_config_options["account_email"] = "bala1@freshdesk.com"
    @app_config_options["contact_email"] = "bala1@freshdesk.com"
    @app_config_options["lead_email"] = "bala1@freshdesk.com"
    post :settings_update, {:controller => "integrations/dynamics_crm", :action =>"settings_update",
                            :app_name => "dynamicscrm",
                            :configs => @app_config_options }
    flash[:error].should include("is not a valid email address for the Entity type")
  end

  it "On the settings page it should pass when the lead/account emails are not present" do
    @app_config_options["account_email"] = "bala@freshdesk.com"
    @app_config_options["contact_email"] = "bala@freshdesk.com"
    @app_config_options["lead_email"] = "bala@freshdesk.com"
    post :settings_update, {:controller => "integrations/dynamics_crm", :action =>"settings_update",
                            :app_name => "dynamicscrm",
                            :configs => @app_config_options }
    flash[:error].should eql nil
    response.should render_template("integrations/applications/dynamics_crm/dynamics_fields")
  end

  it "On the fields page update the user selected values should be updated to DB and integration enabled message should be shown" do
    new_installed_application = FactoryGirl.build(:installed_application, :application_id => "26",
                                        :account_id => @account.id,
                                        :configs => @installed_app_config_options
                                        )
    @installed_application = new_installed_application.save(:validate => false)
    post :fields_update, {:controller => "integrations/dynamics_crm", :action => "fields_update",
                          :app_name => 'dynamicscrm',
                          :account_labels => "Job Title,Telephone,Mobile Phone,Address,Owner",
                          :accounts => ["attributes.jobtitle", "attributes.telephone1", "attributes.mobilephone", "attributes.address1_composite", "attributes.ownerid['Name']"],
                          :contact_labels => "Job Title,new_contactcustomfield,Telephone,Mobile Phone,Address,Owner",
                          :contacts => ["attributes.jobtitle", "attributes.new_contactcustomfield", "attributes.telephone1", "attributes.mobilephone", "attributes.address1_composite", "attributes.ownerid['Name']"],
                          :lead_labels => "Job Title,Telephone,Mobile Phone,Address,Owner",
                          :leads => ["attributes.jobtitle", "attributes.telephone1", "attributes.mobilephone", "attributes.address1_composite", "attributes.ownerid['Name']"]
                        }
    flash[:notice].should eql "The integration has been enabled successfully!"
    response.status.should eql 302
  end

  it "Fetch details on the ticket/contact page should get a valid json response that has the admin selected fields" do
    new_installed_application = FactoryGirl.build(:installed_application, :application_id => "26",
                                        :account_id => @account.id,
                                        :configs => @installed_app_config_options
                                        )
    @installed_application = new_installed_application.save(:validate => false)
    post :widget_data, {:controller => "integrations/dynamics_crm", :action => "widget_data",
                        :app_name => 'dynamicscrm', :email => "bala@freshdesk.com" }
    parsed_body = JSON.parse(response.body)
    parsed_body.each do |entity_map|
      entity_name = entity_map["internal_use_entity_type"]
      new_installed_application[:configs][:inputs]["#{entity_name}_labels"].split(",").each do |label|
        true.should eql entity_map.has_key?(label)
      end
    end
  end

  it "fetch details should return a blank array when no email is match is found with Dynamics" do
    new_installed_application = FactoryGirl.build(:installed_application, :application_id => "26",
                                    :account_id => @account.id,
                                    :configs => @installed_app_config_options
                                    )
    @installed_application = new_installed_application.save(:validate => false)
    get :widget_data, { :controller => "integrations/dynamics_crm", :action => "widget_data",
                        :app_name => 'dynamicscrm', :email => "bala1@freshdesk.com" }
    parsed_body = JSON.parse(response.body)
    true.should eql parsed_body.blank?
  end

  #requires config data to be present in DB so placing it as the last example.
  it "should show the dynamics fields page on clicking the the integration edit button" do
    get :edit, {:controller=>"integrations/dynamics_crm", :action=>"edit",:app_name=>"dynamicscrm"}
    response.should render_template("integrations/applications/dynamics_crm/dynamics_fields")
  end

end