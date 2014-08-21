require 'spec_helper'

describe Support::Discussions::ForumsController do
	# integrate_views
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
		@category = create_test_category
		@forum = create_test_forum(@category)
		@user = add_new_user(@account)
	end

	before(:each) do
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

		response.should redirect_to support_login_url
	end

	it "should redirect to support home if portal forums is disabled" do
		forum = create_test_forum(@category)
		@account.features.hide_portal_forums.create
	 	
	 	put :toggle_monitor, :id => forum.id
	 	response.should redirect_to "/support/home"

	 	get :show, :id => forum.id
	 	response.should redirect_to "/support/home"	

	 	@account.features.hide_portal_forums.destroy
	end

end
