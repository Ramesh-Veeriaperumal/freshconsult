require 'spec_helper'

describe Admin::Ecommerce::AccountsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.features.ecommerce.create
  end

  before(:each) do
    login_admin
  end

  it "should list all ecommerce accounts" do
    get :index
    response.should render_template "admin/ecommerce/accounts/index"
  end


end