require 'spec_helper'
require 'support/salesforce_helper'

RSpec.describe Integrations::SalesforceController do
  include SalesforceHelper
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  setup :activate_authlogic

  before(:all) do
    @agent = add_test_agent(@account)
    key_options = { :account_id => @account.id, :provider => "salesforce"}
    @key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
    #WebMock.disable_net_connect!
  end

  before(:each) do
    log_in(@agent)
    stub_request(:get, "https://ap2.salesforce.com/services/data/v20.0/sobjects/Contact/describe").to_return(:body => contact_fields_response.to_json, :status => 200)
    stub_request(:get, "https://ap2.salesforce.com/services/data/v20.0/sobjects/Account/describe").to_return(:body => account_fields_response.to_json, :status => 200)
    stub_request(:get, "https://ap2.salesforce.com/services/data/v20.0/sobjects/Lead/describe").to_return(:body => lead_fields_response.to_json, :status => 200)
    stub_request(:get, "https://ap2.salesforce.com/services/data/v20.0/sobjects/Opportunity/describe").to_return(:body => opportunity_fields_response.to_json, :status => 200)
  end

  describe "on installation" do
    before(:all) do
      Redis::KeyValueStore.new(@key_spec, app_configs.to_json, {:group => :integration, :expire => 300}).set_key
    end

    it "should render the fields selection page" do
      get :new
      expect(response).to render_template("integrations/applications/salesforce_fields")
      expect(response.body).to include("install")
    end

    it "should install the app on clicking install button in fields selection page" do
      post :install, default_inst_app_params
      expect(response).to redirect_to("/integrations/applications")
      expect(flash[:notice]).to eql I18n.t(:'flash.application.install.success')
      installed_app = @account.installed_applications.with_name("salesforce").first
      expect(installed_app).to be_present
      installed_app.destroy
    end

    it "with feature enabled, should install the app and also populate the tables app_business_rules and va_rules with update & create triggers" do
      enable_sync_feature(@account)
      post :install, default_inst_app_params.merge({ :salesforce_sync_option => { :value => "1" } })
      installed_app = @account.installed_applications.with_name("salesforce").first
      expect(installed_app).to be_present
      expect(installed_app.configs_salesforce_sync_option.to_bool).to eq true
      expect(installed_app.app_business_rules).to be_present
      expect(installed_app.va_rules).to be_present
      installed_app.destroy
      disable_sync_feature(@account)
    end

    after(:all) do
      Redis::KeyValueStore.new(@key_spec).remove_key
    end
  end

  describe "on update" do
    before(:each) do
      @installed_app = create_installed_applications({:account_id => @account.id, :application_name => "salesforce", :configs => { :inputs => app_configs.merge(default_inst_app_configs) } })
    end

    it "should render the fields selection page on edit" do
      get :edit
      expect(response).to render_template("integrations/applications/salesforce_fields")
      expect(response.body).to include("update")
    end

    it "should deactivate the va_rules on disabling the sync option in fields selection page" do
      enable_sync_feature(@account)
      @installed_app.configs[:inputs]["salesforce_sync_option"] = "1"
      @installed_app.save!
      create_va_rules(@installed_app)
      post :update, default_inst_app_params.merge({ :salesforce_sync_option => { :value => "0" } })
      installed_app = @account.installed_applications.with_name("salesforce").first
      va_rules_status = installed_app.va_rules.map do |va_rule| va_rule.active end
      expect(va_rules_status).to eq [ false, false ]
      disable_sync_feature(@account)
    end

    it "should update the installed application on enabling the sync feature post installation" do
      enable_sync_feature(@account)
      post :update, default_inst_app_params.merge({ :salesforce_sync_option => { :value => "1" } })
      installed_app = @account.installed_applications.with_name("salesforce").first
      expect(installed_app.app_business_rules).to be_present
      expect(installed_app.va_rules).to be_present
      disable_sync_feature(@account)
    end

    it "should deactivate the va_rules on update when the feature is disabled from the backend" do
      enable_sync_feature(@account)
      @installed_app.configs[:inputs]["salesforce_sync_option"] = "1"
      @installed_app.save!
      create_va_rules(@installed_app)
      disable_sync_feature(@account)
      post :update, default_inst_app_params.merge({ :opportunity_view => { :value => "0" } })
      installed_app = @account.installed_applications.with_name("salesforce").first
      va_rules_status = installed_app.va_rules.map do |va_rule| va_rule.active end
      expect(va_rules_status).to eq [ false, false ]
    end

    it "should update the installed application with opportunity view and agent settings enabled" do
      post :update, default_inst_app_params.merge({ :opportunities => ["Name","StageName","CloseDate"], :opportunity_labels => "Name,Stage Name,Close Date", :opportunity_view => { :value => "1" }, :agent_settings => { :value => "1" } })
      installed_app = @account.installed_applications.with_name("salesforce").first
      expect(installed_app.configs_opportunity_view.to_bool).to eq true
      expect(installed_app.configs_agent_settings.to_bool).to eq true
    end

    it "should update the installed application with opportunity agent settings disabled" do
      @installed_app.configs[:inputs]["opportunity_fields"] = "Name,StageName,CloseDate"
      @installed_app.configs[:inputs]["opportunity_labels"] = "Name,Stage Name,Close Date"
      @installed_app.configs[:inputs]["opportunity_view"] = "1"
      @installed_app.configs[:inputs]["agent_settings"] = "1"
      @installed_app.save!
      post :update, default_inst_app_params.merge({ :opportunities => ["Name","StageName","CloseDate"], :opportunity_labels => "Name,Stage Name,Close Date", :opportunity_view => { :value => "1" }, :agent_settings => { :value => "0" } })
      installed_app = @account.installed_applications.with_name("salesforce").first
      expect(installed_app.configs_agent_settings.to_bool).to eq false
    end

    after(:each) do
      @installed_app.destroy
    end
  end

  describe "hitting the controller actions without installing the app" do
    it "should redirect to applications/index page on hitting edit action explicitly" do
      get :edit
      expect(response).to redirect_to '/integrations/applications'
      expect(flash[:error]).to eql I18n.t(:'flash.application.not_installed')
    end

    it "should redirect to applications/index page on hitting new action explicitly" do
      get :new
      expect(response).to redirect_to '/integrations/applications'
      expect(flash[:error]).to eql I18n.t(:'flash.application.install.error')
    end
  end

  after(:all) do
    #WebMock.allow_net_connect!
  end
end
