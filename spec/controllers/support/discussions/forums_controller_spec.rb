require File.expand_path("#{File.dirname(__FILE__)}/../../../spec_helper")

describe Support::Discussions::ForumsController do
	integrate_views
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
		@account = create_test_account
		@category = create_test_category
		@forum = create_test_forum(@category)
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

	it "should show the forum on get 'show'" do
		get :show, :id => @forum.id

		response.should render_template "support/discussions/forums/show.portal"
	end

	it "should render 404 on get 'show' if forum is not available" do
		forum = create_test_forum(@category)
		forum_id = forum.id
		forum.destroy

		get :show, :id => forum_id

		response.should render_template "#{Rails.root}/public/404.html"
	end


	it "should render 404 on get 'show' if forum is not visible" do
		forum = change_visibility(create_test_forum(@category), Forum::VISIBILITY_KEYS_BY_TOKEN[:agents])

		get :show, :id => forum.id

		response.should render_template "#{Rails.root}/public/404.html"
	end
	
end