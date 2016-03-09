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
      expected_response = { "extensions" => extensions.body }.merge( {"categories" => all_categories.body}).merge(selecte_params(url_params)).stringify_keys
      expect(JSON.parse(response.body)).to eq(expected_response)
    end
  end

  describe "GET show" do
    it "renders the extension show page" do
      url_params = { type: "#{Marketplace::Constants::EXTENSION_TYPE[:plug]}", version_id: '1' }
      controller.stubs(:extension_details).returns(extension_details)
      controller.stubs(:install_status).returns(install_status)
      get :show, url_params
      expected_response = extension_details.body.merge(install_status.body).merge(selecte_params(url_params)).stringify_keys
      expect(JSON.parse(response.body)).to eq(expected_response)
    end
  end

end