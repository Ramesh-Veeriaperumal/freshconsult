require 'spec_helper'

describe Support::DiscussionsController do
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
		@category = create_test_category
		@user = add_new_user(@account)
	end

	before(:each) do
        @request.env['HTTP_REFERER'] = 'support/discussions'
        log_in(@user)
	end

	after(:all) do
		@category.destroy
	end

	it "should render index page on get 'index'" do
		get :index

		response.should render_template "support/discussions/index"
	end

	it "should render show page on get 'show'" do
		get :show, :id => @category.id

		response.should render_template "support/discussions/show"
	end

	# it "should render index page on get 'show'" do
	# 	get :user_monitored, :user_id => @user.id,
	# 						:page => 1,
	# 						:count_per_page => 5

	# 	response.should render_template "support/discussions/show"
	# end


	it "should render 404 for accounts without forum feature" do
		@account.remove_feature(:forums)
		@account.reload

		get :index
		response.status.should eql(404)

		get :show, :id => @category.id
		response.status.should eql(404)

		@account.add_features(:forums)
		@account.reload
	end
end
