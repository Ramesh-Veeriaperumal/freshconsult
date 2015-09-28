require 'spec_helper'

RSpec.describe Admin::HomeController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should not display ecommerce if feature not enabled" do
    @account.features.ecommerce.destroy
    @account.reload
    get :index
    response.body.should_not =~ /Ecommerce/
  end

  it "should display ecommerce if feature enabled" do
    @account.features.ecommerce.create
    @account.reload
    get :index
    response.body.should =~ /Ecommerce/
  end
end