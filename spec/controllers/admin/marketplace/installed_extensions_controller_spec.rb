require 'spec_helper'
load 'spec/support/marketplace_helper.rb'
RSpec.configure do |c|
  c.include MarketplaceHelper
end

describe Admin::Marketplace::InstalledExtensionsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @env = Rails.env
  end

  before(:each) do
    login_admin
  end

  describe "GET new_configs" do
    it "gets the extension configs" do
      url_params = { extension_id: "1", version_id: "1"}
      controller.stubs(:extension_configs).returns(ext_configs)
      get :new_configs, url_params
      expect(controller.instance_variable_get("@configs")).to eq(ext_configs.body)
    end
  end

  describe "GET edit_configs" do
    it "gets the account configs" do
      url_params = { extension_id: "1", version_id: "1" }
      controller.stubs(:extension_configs).returns(ext_configs)
      controller.stubs(:account_configs).returns(account_configs)
      get :edit_configs, url_params
      expect(controller.instance_variable_get("@configs")).to eq(account_configurations)
    end
  end

  describe "POST install" do
    it "installs the extension" do
      controller.stubs(:extension_details).returns(extension_details)
      controller.stubs(:install_extension).returns(success_response)
      post :install, { extension_id: 1, version_id: 1, configs: nil }
      expect(response.body).to eq(success_response.body)
      expect(response.status).to eq(200)
    end
  end

  describe "PUT reinstall" do
    it "reinstalls the extension" do
      controller.stubs(:update_extension).returns(success_response)
      controller.stubs(:extension_details).returns(extension_details)
      put :reinstall, { extension_id: 1, version_id: 1, configs: account_configs.body }
      expect(response.body).to eq(success_response.body)
      expect(response.status).to eq(200)
    end
  end

  describe "PUT enable" do
    it "reinstalls the extension" do
      controller.stubs(:update_extension).returns(success_response)
      put :enable, { extension_id: 1, version_id: 1 }
      expect(response.body).to eq(success_response.body)
      expect(response.status).to eq(200)
    end
  end

  describe "PUT disable" do
    it "reinstalls the extension" do
      controller.stubs(:update_extension).returns(success_response)
      put :disable, { extension_id: 1, version_id: 1 }
      expect(response.body).to eq(success_response.body)
      expect(response.status).to eq(200)
    end
  end

  describe "DELETE uninstall" do
    it "deletes the extension" do
      controller.stubs(:uninstall_extension).returns(success_response)
      delete :uninstall, { extension_id: 1 }
      expect(response.body).to eq(success_response.body)
      expect(response.status).to eq(200)
    end
  end

end