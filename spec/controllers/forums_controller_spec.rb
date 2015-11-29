require 'spec_helper'
require './app/controllers/forums_controller'
describe ::ForumsController do
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
		@category = create_test_category
		@agent = add_test_agent(@account)
	end

	before(:each) do
	    log_in(@agent)
	end

	it "should redirect to new forum page on 'new'" do
		get :new, :category_id => @category.id

		response.should redirect_to new_discussions_forum_path
	end

	it "should redirect to discussions forums page on 'index'" do
		get :index, :category_id => @category.id

		response.should redirect_to '/discussions'
	end

	it "should redirect to discussions forum show page on 'show'" do
		forum = create_test_forum(@category)

		get :show, :category_id => @category.id, :id => forum.id

		response.should redirect_to discussions_forum_path(forum)
	end

	it "should redirect to edit discussions forum page on 'edit'" do
		forum = create_test_forum(@category)

		get :edit, :category_id => @category.id, :id => forum.id

		response.should redirect_to edit_discussions_forum_path(forum)
	end

end