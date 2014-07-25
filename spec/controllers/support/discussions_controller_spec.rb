require 'spec_helper'

describe Support::DiscussionsController do
	integrate_views
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

		response.should render_template "support/discussions/index.portal"
	end

	it "should render index page on get 'show'" do
		get :show, :id => @category.id

		response.should render_template "support/discussions/show.portal"
	end

	it "should redirect to support home if portal forums is disabled" do
		@account.features.hide_portal_forums.create

		get :show, :id => @category.id
		response.should redirect_to "/support/home"

		get :index
		response.should redirect_to "/support/home"

		get :user_monitored
		response.should redirect_to "/support/home"

		@account.features.hide_portal_forums.destroy		
	end

	# it "should render index page on get 'show'" do
	# 	get :user_monitored, :user_id => @user.id,
	# 						:page => 1,
	# 						:count_per_page => 5

	# 	response.should render_template "support/discussions/show.portal"
	# end



end