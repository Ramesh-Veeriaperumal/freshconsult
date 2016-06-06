require 'spec_helper'

describe Integrations::DynamicscrmController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do

    @app_config_options = { "domain" => "sumit08@freshdesk.onmicrosoft.com", 
                            "password" => "abcd_1234",
                            "instance_type" => "On-Demand", 
                            "organization_name" => "org46253825",
                            "endpoint" => "https://freshdesk.api.crm5.dynamics.com/XRMServices/2011/Organization.svc",
                            "email" => "sumit.a@freshdesk.com", 
                            "lead_email" => "someonel2@example.com",
                            "account_email" => "someone9@example.com", 
                            "contact_email" => "someone_j@example.com"
                          }
    @installed_app_config_options = { :inputs => { 'domain' => "sumit08@freshdesk.onmicrosoft.com",
                                      "instance_type" => "On-Demand",
                                      "organization_name" => "org46253825",
                                      "endpoint" => "https://freshdesk.api.crm5.dynamics.com/XRMServices/2011/Organization.svc",
                                      "account_email" => "someone9@example.com",
                                      "contact_email" => "someone_j@example.com",
                                      "lead_email" => "someonel2@example.com",
                                      "password" => "|Tw9s5bcE/H11FAAkKW0E2308ZgkMnDXNwey4ZfMp+ojhsMIkwquH8DCY0U+HutmZkap6caU7PfGhg3fpnvaZNz2Vl8l7str5Xw6wyrPE0iSsziSluNLhf3tL/yt4QGbSzDPWuvat8BuAvrSoziCJf1itVLZujiBrj5VJfp/EH/5T3LfWjARCctH7yLPOu4rPSXfOOxRM4yQLRv96wMmq4LY/SmzfZTM4a3ly3VMF3Qjuc/RkG9uMfkBXg2m6lBGJy+8dIJKhj0RzFBx9jbwCV4eaL5NSvraG2Ml4aXAQRL1DS5VyP77DVjDyAvzgNOxVZaQ1nab0gp2R40j3RSP3sw==",
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
    get :settings, {:controller=>"integrations/dynamicscrm", :action=>"settings",:app_name=>"dynamicscrm"}
    response.should render_template("integrations/applications/dynamicscrm/dynamicscrm_settings")
  end

  it "On the passing valid credentials and email id it should save values to the DB and show the dynamics_fields page" do
    DynamicsCRM::Client.any_instance.stubs(:authenticate).returns(true)
    Integrations::Constants::CRM_MODULE_TYPES.each do |m_type|
      data = {"EntityName"=>"#{m_type}", "MinActiveRowVersion"=>-1,"MoreRecords"=>false, "PagingCookie"=>"<cookie page=\"1\"><contactid last=\"{8632E44A-32FA-E511-80E7-C4346BAC1998}\" first=\"{8632E44A-32FA-E511-80E7-C4346BAC1998}\" /></cookie>", "TotalRecordCount"=>-1, "TotalRecordCountLimitExceeded"=>false, :entities => [{"attributes"=> {"address1_composite"=>"5086 Nottingham Place\r\nDuvall, WA 16982\r\nU.S.", "ownerid"=>{"Id"=>"8e18590e-12ae-4882-b7f1-cc596407feb9", "KeyAttributes"=>nil, "LogicalName"=>"systemuser", "Name"=>"Sumit Agarwal", "RowVersion"=>nil}, "jobtitle"=>"Purchasing Assistant"}, "entity_state"=>nil, "formatted_values"=> {"customertypecode"=>"Default Value", "merged"=>"No"}, "id"=>"8632e44a-32fa-e511-80e7-c4346bac1998","related_entities"=>nil}]}
      data[:entities][0] = OpenStruct.new(data[:entities].first)
      DynamicsCRM::Client.any_instance.stubs(:retrieve_multiple).with("#{m_type}", [["emailaddress1", "Equal", @app_config_options["#{m_type}_email"]]]).returns(data)
    end
    post :settings_update, {:controller => "integrations/dynamicscrm", :action =>"settings_update", :app_name => "dynamicscrm", :configs => @app_config_options }
    installed_application = @account.installed_applications.with_name("dynamicscrm").first
    installed_application[:configs][:inputs]["domain"].should eql "sumit08@freshdesk.onmicrosoft.com"
    installed_application.configsdecrypt_password.should eql "abcd_1234"
    installed_application[:configs][:inputs]["lead_email"].should eql "someonel2@example.com"
    installed_application[:configs][:inputs]["contact_email"].should eql "someone_j@example.com"
    installed_application[:configs][:inputs]["account_email"].should eql "someone9@example.com"
    #since the passed values are valid it should update the db and should take to the next dynamics_field page
    response.should render_template("integrations/applications/form/crm_custom_fields_form")
    @account.installed_applications.with_name("dynamicscrm").first.delete
  end

  it "On the settings update it should show validation message for wrong user name or password" do
    @app_config_options["domain"] = "sumit@freshdesk.onmicrosoft.com"
    DynamicsCRM::Client.any_instance.stubs(:authenticate).returns(false)
    post :settings_update, {:controller => "integrations/dynamicscrm", :action =>"settings_update", :app_name => "dynamicscrm", :configs => @app_config_options }
    flash[:error].should eql "Oops, something went wrong! Please verify if you have entered correct values."
  end

  it "On the settings update it should show validation message for a wrong contact/lead/account email" do
    @app_config_options["domain"] = "sumit08@freshdesk.onmicrosoft.com"
    @app_config_options["account_email"] = "someone@example.com"
    @app_config_options["contact_email"] = "someone@example.com"
    @app_config_options["lead_email"] = "someone@example.com"
    DynamicsCRM::Client.any_instance.stubs(:authenticate).returns(true)
    Integrations::Constants::CRM_MODULE_TYPES.each do |m_type|
      data = {"EntityName"=>"#{m_type}", "MinActiveRowVersion"=>-1, "MoreRecords"=>false, "PagingCookie"=>nil, "TotalRecordCount"=>-1, "TotalRecordCountLimitExceeded"=>false, :entities=>[]}
      DynamicsCRM::Client.any_instance.stubs(:retrieve_multiple).with("#{m_type}", [["emailaddress1", "Equal", @app_config_options["#{m_type}_email"]]]).returns(data)
    end
    post :settings_update, {:controller => "integrations/dynamicscrm", :action =>"settings_update", :app_name => "dynamicscrm", :configs => @app_config_options }
    flash[:error].should include("is not a valid email address for the Entity type")
  end

  it "On the settings page it should pass when the lead/account emails are not present" do
    @app_config_options["contact_email"] = "someone_j@example.com"
    @app_config_options["account_email"] = nil
    @app_config_options["lead_email"] = nil
    DynamicsCRM::Client.any_instance.stubs(:authenticate).returns(true)
    data = {"EntityName"=>"contact", "MinActiveRowVersion"=>-1,"MoreRecords"=>false, "PagingCookie"=>"<cookie page=\"1\"><contactid last=\"{8632E44A-32FA-E511-80E7-C4346BAC1998}\" first=\"{8632E44A-32FA-E511-80E7-C4346BAC1998}\" /></cookie>", "TotalRecordCount"=>-1, "TotalRecordCountLimitExceeded"=>false, :entities => [{"attributes"=> {"address1_composite"=>"5086 Nottingham Place\r\nDuvall, WA 16982\r\nU.S.", "ownerid"=>{"Id"=>"8e18590e-12ae-4882-b7f1-cc596407feb9", "KeyAttributes"=>nil, "LogicalName"=>"systemuser", "Name"=>"Sumit Agarwal", "RowVersion"=>nil}, "jobtitle"=>"Purchasing Assistant"}, "entity_state"=>nil, "formatted_values"=> {"customertypecode"=>"Default Value", "merged"=>"No"}, "id"=>"8632e44a-32fa-e511-80e7-c4346bac1998","related_entities"=>nil}]}
    data[:entities][0] = OpenStruct.new(data[:entities].first)
    DynamicsCRM::Client.any_instance.stubs(:retrieve_multiple).with("contact", [["emailaddress1", "Equal", @app_config_options["contact_email"]]]).returns(data)
    post :settings_update, {:controller => "integrations/dynamicscrm", :action =>"settings_update", :app_name => "dynamicscrm", :configs => @app_config_options }
    flash[:error].should eql nil
    response.should render_template("integrations/applications/form/crm_custom_fields_form")
    @account.installed_applications.with_name("dynamicscrm").first.delete
  end

  it "On the fields page update the user selected values should be updated to DB and integration enabled message should be shown" do
    new_installed_application = FactoryGirl.build(:installed_application, :application_id => "31", :account_id => @account.id, :configs => @installed_app_config_options
                                        )
    @installed_application = new_installed_application.save(:validate => false)
    post :fields_update, {:controller => "integrations/dynamicscrm", :action => "fields_update",
                          :app_name => 'dynamicscrm',
                          :account_labels => "Job Title,Telephone,Mobile Phone,Address,Owner",
                          :accounts => ["attributes.jobtitle", "attributes.telephone1", "attributes.mobilephone", "attributes.address1_composite", "attributes.ownerid['Name']"],
                          :contact_labels => "Job Title,new_contactcustomfield,Telephone,Mobile Phone,Address,Owner",
                          :contacts => ["attributes.jobtitle", "attributes.new_contactcustomfield", "attributes.telephone1", "attributes.mobilephone", "attributes.address1_composite", "attributes.ownerid['Name']"],
                          :lead_labels => "Job Title,Telephone,Mobile Phone,Address,Owner",
                          :leads => ["attributes.jobtitle", "attributes.telephone1", "attributes.mobilephone", "attributes.address1_composite", "attributes.ownerid['Name']"]
                        }
    flash[:notice].should eql "App installed successfully."
    response.status.should eql 302
    @account.installed_applications.with_name("dynamicscrm").first.delete
  end

  it "Fetch details on the ticket/contact page should get a valid json response that has the admin selected fields" do
    DynamicsCRM::Client.any_instance.stubs(:authenticate).returns(true)
    Integrations::Constants::CRM_MODULE_TYPES.each do |m_type|
      data = {"EntityName"=>"#{m_type}", "MinActiveRowVersion"=>-1,"MoreRecords"=>false, "PagingCookie"=>"<cookie page=\"1\"><contactid last=\"{8632E44A-32FA-E511-80E7-C4346BAC1998}\" first=\"{8632E44A-32FA-E511-80E7-C4346BAC1998}\" /></cookie>", "TotalRecordCount"=>-1, "TotalRecordCountLimitExceeded"=>false, :entities => [{"attributes"=> {"address1_composite"=>"5086 Nottingham Place\r\nDuvall, WA 16982\r\nU.S.", "ownerid"=>{"Id"=>"8e18590e-12ae-4882-b7f1-cc596407feb9", "KeyAttributes"=>nil, "LogicalName"=>"systemuser", "Name"=>"Sumit Agarwal", "RowVersion"=>nil}, "jobtitle"=>"Purchasing Assistant"}, "entity_state"=>nil, "formatted_values"=> {"customertypecode"=>"Default Value", "merged"=>"No"}, "id"=>"8632e44a-32fa-e511-80e7-c4346bac1998","related_entities"=>nil}]}
      data[:entities][0] = OpenStruct.new(data[:entities].first)
      data[:entities][0].attributes = OpenStruct.new(data[:entities].first.attributes)
      DynamicsCRM::Client.any_instance.stubs(:retrieve_multiple).with("#{m_type}", [["emailaddress1", "Equal", "sumit.a@freshdesk.com"]]).returns(data)
    end
    new_installed_application = FactoryGirl.build(:installed_application, :application_id => "31", :account_id => @account.id, :configs => @installed_app_config_options)
    @installed_application = new_installed_application.save(:validate => false)
    post :widget_data, {:controller => "integrations/dynamicscrm", :action => "widget_data", :app_name => 'dynamicscrm', :email => "sumit.a@freshdesk.com" }
    parsed_body = JSON.parse(response.body)
    parsed_body.each do |entity_map|
      entity_name = entity_map["internal_use_entity_type"]
      new_installed_application[:configs][:inputs]["#{entity_name}_labels"].split(",").each do |label|
        true.should eql entity_map.has_key?(label)
      end
    end
    @account.installed_applications.with_name("dynamicscrm").first.delete
  end

  it "fetch details should return a blank array when no email is match is found with Dynamics" do
    DynamicsCRM::Client.any_instance.stubs(:authenticate).returns(true)
    Integrations::Constants::CRM_MODULE_TYPES.each do |m_type|
      data = {"EntityName"=>"#{m_type}", "MinActiveRowVersion"=>-1, "MoreRecords"=>false, "PagingCookie"=>nil, "TotalRecordCount"=>-1, "TotalRecordCountLimitExceeded"=>false, :entities=>[]}
      DynamicsCRM::Client.any_instance.stubs(:retrieve_multiple).with("#{m_type}", [["emailaddress1", "Equal", "sumit.a@freshdesk.com"]]).returns(data)
    end
    new_installed_application = FactoryGirl.build(:installed_application, :application_id => "31", :account_id => @account.id, :configs => @installed_app_config_options)
    @installed_application = new_installed_application.save(:validate => false)
    get :widget_data, { :controller => "integrations/dynamicscrm", :action => "widget_data", :app_name => 'dynamicscrm', :email => "sumit.a@freshdesk.com" }
    parsed_body = JSON.parse(response.body)
    true.should eql parsed_body.blank?
  end

  #requires config data to be present in DB so placing it as the last example.
  it "should show the dynamics fields page on clicking the the integration edit button" do
    get :edit, {:controller=>"integrations/dynamicscrm", :action=>"edit",:app_name=>"dynamicscrm"}
    response.should render_template("integrations/applications/form/crm_custom_fields_form")
  end

end