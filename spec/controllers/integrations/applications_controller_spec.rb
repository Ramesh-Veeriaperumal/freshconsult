require 'spec_helper'
RSpec.configure do |c|
  c.include MemcacheKeys
end

RSpec.describe Integrations::ApplicationsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @agent = add_test_agent(@account)
    @new_application = FactoryGirl.build(:application, 
                                    :name => "Test Application",
                                    :listing_order => 24,
                                    :options => {
                                      :script => "<div></div>",
                                      :display_in_pages => ["helpdesk_tickets_show_page_side_bar"],
                                      :oauth_url => "/auth/test_integration?origin=id%3D{{account_id}}",
                                      :keys_order => [:api_key, :application_update],
                                      :api_key => { :type => :text, :required => true,
                                                      :label => "integrations.new_application.api_key",
                                                      :info => "integrations.new_application.api_key_info"}
                                                  },
                                    :application_type => "freshplug",
                                    :account_id => @account.id)
    @new_application.save(validate: false)
    @widget = FactoryGirl.build(:widget, :application_id => @new_application.id)
    @widget.save(:validate => false)
    @new_installed_app = FactoryGirl.build(:installed_application, :application_id => @new_application.id,
                                              :account_id => @account.id,
                                              :configs => { :inputs => { "refresh_token" => "7977697105566556112", 
                                                            "oauth_token" => "61837911-03ab-485a-9903-fb6dbbbf7b46", 
                                                            "uid" => "roshiniphilip@gmail.com"}
                                                          }
                                              )
    @new_installed_app.save(validate: false)
  end

  before(:each) do
    log_in(@agent)
  end

  it "renders the application index template" do
    get 'index'
    response.should render_template "integrations/applications/index"
  end

  it "should install surveymonkey application and redirect to edit(configurable)" do
    provider = "surveymonkey"
    set_redis_key(provider, surveymonkey_params(provider))
    post 'oauth_install', :id => provider
    get_redis_key(provider).should be_nil
    installed_app = Integrations::InstalledApplication.with_name(provider).first
    installed_app.should_not be_nil
    response.should redirect_to edit_integrations_installed_application_path(installed_app)
  end

  it "should install slack application and redirect to edit(configurable)" do
    provider = "slack"
    set_redis_key(provider, slack_params(provider))
    post 'oauth_install', :id => provider
    get_redis_key(provider).should be_nil
    installed_app = Integrations::InstalledApplication.with_name(provider).first
    installed_app.should_not be_nil
    response.should redirect_to edit_integrations_installed_application_path(installed_app)
  end

  it "should update oauth token of installed app" do
    provider = "Test Application"
    access_token = OAuth2::AccessToken.new(OAuth2::Client.new("token_aaa","secret_aaa"), "token_aaa")
    Integrations::ApplicationsController.any_instance.stubs(:get_oauth2_access_token).returns(access_token)
    post 'oauth_install', :id => provider
    @new_installed_app.reload
    @new_installed_app[:configs][:inputs]['oauth_token'].should eql "token_aaa"
    response.should redirect_to "/integrations/applications"
  end

  it "should install salesforce application using oauth token from redis when install params is nil" do
    provider = "salesforce"
    set_redis_key(provider, salesforce_params(provider))
    Integrations::ApplicationsController.any_instance.stubs(:fetch_sf_contact_fields).returns({"Id"=>"Contact ID"})
    Integrations::ApplicationsController.any_instance.stubs(:fetch_sf_lead_fields).returns({"Id"=>"Lead ID"})
    Integrations::ApplicationsController.any_instance.stubs(:fetch_sf_account_fields).returns({"Id"=>"Account ID"})
    post 'oauth_install', :id => provider
    get_redis_key(provider).should_not be_nil
    Integrations::InstalledApplication.with_name(provider).should_not be_nil
    response.should render_template "integrations/applications/salesforce_fields"
  end

  it "should install salesforce application using oauth token from redis" do
    provider = "salesforce"
    set_redis_key(provider, salesforce_params(provider))
    post 'oauth_install', :id => provider, :install => true, :contacts => ["Name","Id","Account_Id"], 
          :leads => ["Name","Id"], :accounts => ["Name","Id"], :contact_labels => "Full Name,Contact ID,Account ID", 
          :lead_labels => "Full Name,Lead ID", :account_labels => "Account Name,Account ID"
    get_redis_key(provider).should be_nil
    Integrations::InstalledApplication.with_name(provider).should_not be_nil
    response.should redirect_to "/integrations/applications"
  end

  it "should raise exception when salesforce application is installed with invalid params" do
    provider = "salesforce"
    set_redis_key(provider, salesforce_params(provider))
    post 'oauth_install', :id => provider, :install => true, :contacts => "Account_Id"
    response.should redirect_to "/integrations/applications"
    error_flash = {:error=>"Error in enabling the integration."}
    request.flash[:error].should eql error_flash[:error]
  end

  it "should install salesforce application using oauth" do
    provider = "salesforce"
    set_redis_key(provider, salesforce_params(provider))
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(:text => '{"fields":[{"name":"name","label":"label"}]}')
    post 'oauth_install', :id => provider
    get_redis_key(provider).should_not be_nil
    Integrations::InstalledApplication.with_name(provider).should_not be_nil
    response.should render_template("integrations/applications/salesforce_fields")
  end

  it "should redirect to dynamics crm " do
    application = FactoryGirl.build(:application, :name => "dynamicscrm",
                                    :display_name => "integrations.dynamicscrm.label",
                                    :listing_order => 29,
                                    :options => {
                                      :direct_install => false
                                    },
                                    :account_id => 0,
                                    :application_type => "dynamicscrm")
    application.save(:validate => false)
    dynamics_id = Integrations::Application.find_by_name("dynamicscrm").id
    get "show",  {:controller => "integrations/applications", :action => "show", :id => dynamics_id }
    response.should redirect_to "/integrations/dynamics_crm/settings"
  end
end