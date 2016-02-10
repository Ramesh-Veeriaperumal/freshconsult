require 'spec_helper'
load 'spec/support/marketplace_helper.rb'
RSpec.configure do |c|
  c.include MarketplaceHelper
end

describe Admin::ExtensionsController do
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
      expected_response = extensions.merge(all_categories).merge(selecte_params(url_params)).to_json
      expect(response.body).to eq(expected_response)
    end

    it "renders the in development extensions listing template" do
      url_params = { type: "#{Marketplace::Constants::EXTENSION_TYPE[:plug]}", in_dev: true }
      controller.stubs(:indev_extensions).returns(extensions)
      controller.stubs(:all_categories).returns(all_categories)
      get :index, url_params
      expected_response = extensions.merge(all_categories).merge(selecte_params(url_params)).to_json
      expect(response.body).to eq(expected_response)
    end
  end

  describe "GET show" do
    it "renders the extension show page" do
      url_params = { type: "#{Marketplace::Constants::EXTENSION_TYPE[:plug]}", id: '1' }
      controller.stubs(:show_extension).returns(show_extension)
      controller.stubs(:install_status).returns(install_status)
      get :show, url_params
      expected_response = show_extension.merge(install_status).merge(selecte_params(url_params)).to_json
      expect(response.body).to eq(expected_response)
    end
  end

  describe "GET search" do
    it "renders the extensions listing template with search query" do
      url_params = { type: "#{Marketplace::Constants::EXTENSION_TYPE[:plug]}", query: "Plug" }
      controller.stubs(:mkp_extensions_search).returns(extensions)
      controller.stubs(:all_categories).returns(all_categories)
      get :search, url_params
      expected_response = extensions.merge(all_categories).merge(selecte_params(url_params)).to_json
      expect(response.body).to eq(expected_response)
    end

    it "renders the in development extensions listing template with search query" do
      url_params = { type: "#{Marketplace::Constants::EXTENSION_TYPE[:plug]}", in_dev: true, query: "Plug" }
      controller.stubs(:indev_extensions_search).returns(extensions)
      controller.stubs(:all_categories).returns(all_categories)
      get :search, url_params
      expected_response = extensions.merge(all_categories).merge(selecte_params(url_params)).to_json
      expect(response.body).to eq(expected_response)
    end
  end

end