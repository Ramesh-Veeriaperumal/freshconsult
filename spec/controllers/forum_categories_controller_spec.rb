require 'spec_helper'

describe ForumCategoriesController do
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
		@agent = add_test_agent(@account)
	end

	before(:each) do
	    log_in(@agent)
	end

	it "should redirect to new discussions page on 'new'" do
		get :new

		response.should redirect_to new_discussion_path
	end

	it "should redirect to discussions page on 'index'" do
		get :index
    
		response.should redirect_to '/discussions'
	end

	it "should redirect to discussions show page on 'show'" do
		category = create_test_category

		get :show, :id => category.id

		response.should redirect_to discussion_path(category)
	end

	it "should redirect to edit discussions page on 'edit'" do
		category = create_test_category

		get :edit, :id => category.id

		response.should redirect_to edit_discussion_path(category)
	end

end