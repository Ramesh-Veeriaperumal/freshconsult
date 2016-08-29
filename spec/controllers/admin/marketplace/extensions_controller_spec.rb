require 'spec_helper'
load 'spec/support/marketplace_helper.rb'
RSpec.configure do |c|
  c.include MarketplaceHelper
end

describe Admin::Marketplace::ExtensionsController do
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

  describe "GET index" do
    it "renders the extensions listing template" do
      url_params = { type: "#{Marketplace::Constants::EXTENSION_TYPE[:plug]}" }
      controller.stubs(:mkp_extensions).returns(extensions)
      controller.stubs(:all_categories).returns(all_categories)
      get :index, url_params
      expect(controller.instance_variable_get("@extensions")).to eq(extensions.body)
      expect(controller.instance_variable_get("@categories")).to eq(all_categories.body)
    end
  end

  describe "GET show" do
    it "renders the extension show page" do
      url_params = { type: "#{Marketplace::Constants::EXTENSION_TYPE[:plug]}", extension_id: '1' }
      controller.stubs(:extension_details).returns(extension_details)
      controller.stubs(:install_status).returns(install_status)
      get :show, url_params
      expect(controller.instance_variable_get("@extension")).to eq(extension_details.body)
      expect(controller.instance_variable_get("@install_status")).to eq(install_status.body)
    end
  end

  describe "GET search" do
    it "renders the extension listing page for the searched query" do
      url_params = { type: "#{Marketplace::Constants::EXTENSION_TYPE[:plug]}", query: "google" }
      controller.stubs(:search_mkp_extensions).returns(extensions)
      controller.stubs(:all_categories).returns(all_categories)
      get :search, url_params
      expect(controller.instance_variable_get("@extensions")).to eq(extensions.body)
      expect(controller.instance_variable_get("@categories")).to eq(all_categories.body)
    end
  end

  describe "GET auto_suggest" do
    it "renders the auto complete suggestions" do
      url_params = { type: "#{Marketplace::Constants::EXTENSION_TYPE[:plug]}", query: "google" }
      controller.stubs(:auto_suggest_mkp_extensions).returns(auto_suggestion)
      get :auto_suggest, url_params
      expect(controller.instance_variable_get("@auto_suggestions")).to eq(auto_suggestion.body)
    end
  end

end