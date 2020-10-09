require 'spec_helper'

describe Support::Discussions::ForumsController do
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

		response.should render_template "support/discussions/forums/show"
	end

	it "should render 404 on get 'show' if forum is not available" do
		forum = create_test_forum(@category)
		forum_id = forum.id
		forum.destroy

		get :show, :id => forum_id
    
		response.should render_template(:file => "#{Rails.root}/public/404.html")
    response.status.should eql(404)
	end


	it "should render 404 on get 'show' if forum is not visible" do
		forum = change_visibility(create_test_forum(@category), Forum::VISIBILITY_KEYS_BY_TOKEN[:agents])

		get :show, :id => forum.id

		response.should redirect_to support_login_url
	end

	it "should render 404 for accounts without forum feature" do
		@account.remove_feature(:forums)
		@account.reload

		get :show, :id => @forum.id
		response.status.should eql(404)

		@account.add_features(:forums)
		@account.reload
	end

end
