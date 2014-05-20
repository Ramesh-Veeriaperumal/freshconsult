require 'spec_helper'

describe Admin::CannedResponses::ResponsesController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@now = (Time.now.to_f*1000).to_i
		@test_response_1 = create_response( {:title => "New Canned_Responses Hepler",:content_html => "DESCRIPTION: New Canned_Responses Hepler",
			:folder_id => 1, :user_id => @user.id, :visibility => 1, :group_id => 1  } )
			@test_response_2 = create_response( {:title => "New Canned_Responses Hepler #{@now}",:content_html => "DESCRIPTION: New Canned_Responses Hepler #{@now}",
			:folder_id => 1, :user_id => @user.id, :visibility => 3, :group_id => 1  } )
			@test_cr_folder_1 = create_cr_folder({:name => "New CR Folder Helper #{@now}"})
	end

	before(:each) do
		@request.env['HTTP_REFERER'] = '/admin/canned_responses/folders'
		log_in(@user)
	end

	it "should create a new Canned Responses" do
		get :new, :folder_id => @test_response_1.folder_id
		response.should render_template("admin/canned_responses/responses/new")
		post :create, { :admin_canned_responses_response => {:title => "New Canned_Responses #{@now}", :content_html => Faker::Lorem.paragraph,
			:visibility => {:user_id => @user.id, :visibility => 2, :group_id => 1}}, :new_folder_id => 1, :folder_id => 1
		}
		canned_response = Admin::CannedResponses::Response.find_by_title("New Canned_Responses #{@now}")
		user_access = Admin::UserAccess.find_by_accessible_id(canned_response.id)
		canned_response.should_not be_nil
		canned_response.folder_id.should eql 1
		user_access.should_not be_nil
		user_access.group_id.should eql 1
	end

	it "should not create a new Canned Responses" do
		get :new, :folder_id => @test_response_1.folder_id
		response.should render_template("admin/canned_responses/responses/new")
		post :create, { :admin_canned_responses_response => {:title => "", :content_html => "New Canned_Responses without title",
			:visibility => {:user_id => @user.id, :visibility => 1, :group_id => 1}}, :new_folder_id => 1, :folder_id => 1
		}
		canned_response = Admin::CannedResponses::Response.find_by_content_html("New Canned_Responses without title")
		canned_response.should be_nil
	end

	it "should show a Canned Responses" do
		get :show, :folder_id => @test_response_1.folder_id,:id => @test_response_1.id
		response.body.should =~ /redirected/
	end

	it "should edit a Canned Responses" do
		get :edit, :folder_id => @test_response_1.folder_id,:id => @test_response_1.id
		response.body.should =~ /#{@test_response_1.title}/
		put :update, { :id => @test_response_1.id,
			:admin_canned_responses_response => {
				:title => "Updated Canned_Responses #{@now}",
				:content_html => "Updated DESCRIPTION: New Canned_Responses Hepler",
				:visibility => {:user_id => @user.id, :visibility => 2, :group_id => 1}
			},
			:new_folder_id => 1,
			:folder_id => "#{@test_response_1.folder_id}"
		}
		canned_response = Admin::CannedResponses::Response.find_by_id(@test_response_1.id)
		access_visibility = Admin::UserAccess.find_by_accessible_id(@test_response_1.id)
		canned_response.title.should eql("Updated Canned_Responses #{@now}")
		canned_response.content_html.should eql("Updated DESCRIPTION: New Canned_Responses Hepler")
		access_visibility.visibility.should eql 2
		access_visibility.group_id.should_not be_nil
	end

	it "should not update a Canned Responses" do
		get :edit, :folder_id => @test_response_1.folder_id,:id => @test_response_1.id
		response.body.should =~ /#{@test_response_1.title}/
		put :update, { :id => @test_response_1.id,
			:admin_canned_responses_response => {:title => "",
				:content_html => "Updated Canned_Responses without title",
				:visibility => {:user_id => @user.id, :visibility => 2, :group_id => 1}
			},
			:new_folder_id => 1,
			:folder_id => "#{@test_response_1.folder_id}"
		}
		canned_response = Admin::CannedResponses::Response.find_by_id(@test_response_1.id)
		canned_response.title.should eql("Updated Canned_Responses #{@now}")
		canned_response.title.should_not eql ""
		canned_response.content_html.should_not eql("Updated Canned_Responses without title")
	end

	it "should update the folder of Canned Responses" do
		put :update_folder, :ids => ["#{@test_response_1.id}","#{@test_response_2.id}"], :move_folder_id => @test_cr_folder_1.id, :folder_id => 1
		canned_response_1 = Admin::CannedResponses::Response.find_by_id(@test_response_1.id)
		canned_response_2 = Admin::CannedResponses::Response.find_by_id(@test_response_2.id)
		canned_response_1.folder_id.should eql(@test_cr_folder_1.id)
		canned_response_2.folder_id.should eql(@test_cr_folder_1.id)
	end

	it "should delete multiple Canned Responses" do
		delete :delete_multiple, :ids => ["#{@test_response_1.id}"]
		canned_response = Admin::CannedResponses::Response.find_by_id(@test_response_1.id)
		canned_response.should be_nil
	end
end
