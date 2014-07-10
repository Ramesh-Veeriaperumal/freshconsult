require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")

describe Support::DiscussionsController do
	integrate_views
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
		@account = create_test_account
		@category = create_test_category
		@user = add_new_user(@account)
	end

	before(:each) do
	    @request.host = @account.full_domain
	    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
	                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
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

	# it "should render index page on get 'show'" do
	# 	get :user_monitored, :user_id => @user.id,
	# 						:page => 1,
	# 						:count_per_page => 5

	# 	response.should render_template "support/discussions/show.portal"
	# end



end