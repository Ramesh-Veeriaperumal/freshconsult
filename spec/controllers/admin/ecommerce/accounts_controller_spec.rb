require 'spec_helper'

RSpec.describe Admin::Ecommerce::AccountsController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:each) do
		login_admin
	end

	it "should render non_covered_feature if feature disabled" do
		@account.features.ecommerce.destroy
		@account.reload
		get :index
		response.should render_template "errors/non_covered_feature"
	end

	it "should render index page if feature enabled" do
		@account.features.ecommerce.create
		@account.reload
    get :index
    response.should render_template "admin/ecommerce/accounts/index"
	end

	it "should list all ecommerce accounts" do
		@account.reload
		get :index
		assigns[:ecommerce_accounts].count.should eql(@account.ecommerce_accounts.count)
	end

end