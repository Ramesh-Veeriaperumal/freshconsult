require 'spec_helper'
load 'spec/support/marketplace_helper.rb'
RSpec.configure do |c|
  c.include MarketplaceHelper
end

describe Admin::InstalledExtensionsController do
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
      controller.stubs(:extension_configs).returns(configs)
      get :new_configs, url_params
      expected_response = selecte_params(url_params).merge({configs: configs.body}).stringify_keys
      expect(JSON.parse(response.body)).to eq(expected_response)
    end
  end

  describe "GET edit_configs" do
    it "gets the account configs" do
      url_params = { extension_id: "1", version_id: "1" }
      controller.stubs(:extension_configs).returns(configs)
      controller.stubs(:account_configs).returns(configs)
      controller.stubs(:account_configurations).returns(configs)
      controller.instance_variable_set("@account_configurations", configs.body)
      get :edit_configs, url_params
      expected_response = selecte_params(url_params).merge({configs: configs.body}).stringify_keys
      expect(JSON.parse(response.body)).to eq(expected_response)
    end
  end

  describe "POST install" do
    it "installs the extension" do
      controller.stubs(:install_extension).returns(status)
      controller.stubs(:extension_details).returns(extension_details)
      controller.instance_variable_set("@post_api", OpenStruct.new({code: 200}))
      post :install, { extension_id: "1", version_id: 1, configs: nil }
      expect(response.status).to eq(200)
    end
  end

  describe "PUT reinstall" do
    it "reinstalls the extension" do
      controller.stubs(:update_extension).returns(status)
      controller.stubs(:extension_details).returns(extension_details)
      controller.instance_variable_set("@put_api", OpenStruct.new({code: 200}))
      put :reinstall, { extension_id: "1", version_id: 1, configs: nil }
      expect(response.status).to eq(200)
    end
  end

  describe "PUT enable" do
    it "reinstalls the extension" do
      controller.stubs(:update_extension).returns({})
      controller.instance_variable_set("@put_api", OpenStruct.new({code: 200}))
      put :enable, { extension_id: "1", version_id: 1 }
      expect(response.status).to eq(200)
    end
  end

  describe "PUT disable" do
    it "reinstalls the extension" do
      controller.stubs(:update_extension).returns({})
      controller.instance_variable_set("@put_api", OpenStruct.new({code: 200}))
      put :disable, { extension_id: "1", version_id: 1 }
      expect(response.status).to eq(200)
    end
  end

  describe "DELETE uninstall" do
    it "deletes the extension" do
      controller.stubs(:uninstall_extension).returns({})
      controller.instance_variable_set("@delete_api", OpenStruct.new({code: 200}))
      delete :uninstall, { extension_id: "1", version_id: 1 }
      expect(response.status).to eq(200)
    end
  end

end