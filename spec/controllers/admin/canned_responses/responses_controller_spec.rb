require 'spec_helper'

describe Admin::CannedResponses::ResponsesController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@now = (Time.now.to_f*1000).to_i
		@group = create_group(RSpec.configuration.account, {:name => "Response grp #{@now}"})
		@folder_id = RSpec.configuration.account.canned_response_folders.find_by_is_default(true).id
		stub_s3_writes
		file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
	    # Create canned responses
		@test_response_1 = create_response( {:title => "New Canned_Responses Hepler",:content_html => "DESCRIPTION: New Canned_Responses Hepler",
			:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
			:attachments => {:resource => file, :description => "" } })
		@test_response_2 = create_response( {:title => "New Canned_Responses Hepler #{@now}",:content_html => "DESCRIPTION: New Canned_Responses Hepler #{@now}",
			:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]} )
		@test_cr_folder_1 = create_cr_folder({:name => "New CR Folder Helper #{@now}"})
	end

	before(:each) do
		@request.env['HTTP_REFERER'] = '/admin/canned_responses/folders'
		stub_s3_writes
		log_in(RSpec.configuration.agent)
	end

	it "should create a new Canned Responses" do
		get :new, :folder_id => @test_response_1.folder_id
		response.should render_template("admin/canned_responses/responses/new")
		post :create, { :admin_canned_responses_response =>{:title => "New Canned_Responses #{@now}", 
															:content_html => Faker::Lorem.paragraph,
															:visibility => {:user_id => RSpec.configuration.agent.id, 
																			:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents], 
																			:group_id => @group.id}
															}, 
						:new_folder_id => @folder_id, :folder_id => @folder_id
		}
		canned_response = RSpec.configuration.account.canned_responses.find_by_title("New Canned_Responses #{@now}")
		user_access = RSpec.configuration.account.user_accesses.find_by_accessible_id(canned_response.id)
		canned_response.should_not be_nil
		canned_response.folder_id.should eql @folder_id
		user_access.should_not be_nil
		user_access.group_id.should eql @group.id
	end

	it "should create a Canned Responses with attachment" do
		post :create, {:admin_canned_responses_response => {:title => "Canned Response with attachment", 
															:content_html => Faker::Lorem.paragraph,
															:attachments => [{:resource => fixture_file_upload('files/image4kb.png', 'image/png', :binary) }],
															:visibility => {:user_id => @agent.id, 
																			:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents], 
																			:group_id => @group.id}
															}, 
						:new_folder_id => @folder_id, :folder_id => @folder_id
		}
		cr_attachment = @account.canned_responses.find_by_title("Canned Response with attachment")
		cr_attachment.should_not be_nil
		user_access = @account.user_accesses.find_by_accessible_id(cr_attachment.id)
		user_access.should_not be_nil
		@account.attachments.last(:conditions=>["content_file_name = ? and attachable_type = ?", "image4kb.png", "Account"]).should_not be_nil
		cr_attachment.shared_attachments.first.should_not be_nil
	end

	it "should not create a new Canned Responses without a title" do
		get :new, :folder_id => @test_response_1.folder_id
		response.should render_template("admin/canned_responses/responses/new")
		post :create, { :admin_canned_responses_response =>{:title => "", 
															:content_html => "New Canned_Responses without title",
															:visibility => {:user_id => RSpec.configuration.agent.id, 
																			:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents], 
																			:group_id => @group.id}
															}, 
						:new_folder_id => @folder_id, :folder_id => @folder_id
		}
		canned_response = RSpec.configuration.account.canned_responses.find_by_content_html("New Canned_Responses without title")
		canned_response.should be_nil
	end

	it "should show a Canned Responses" do
		get :show, :folder_id => @test_response_1.folder_id,:id => @test_response_1.id
		response.body.should =~ /redirected/
	end

	it "should update a Canned Responses" do
		get :edit, :folder_id => @test_response_1.folder_id,:id => @test_response_1.id
		response.body.should =~ /#{@test_response_1.title}/
		put :update, {
			:id => @test_response_1.id,
			:admin_canned_responses_response => {
				:title => "Updated Canned_Responses #{@now}",
				:content_html => "Updated DESCRIPTION: New Canned_Responses Hepler",
				:visibility => {:user_id => RSpec.configuration.agent.id, 
								:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents], 
								:group_id => @group.id}
			},
			:new_folder_id => @folder_id,
			:folder_id => "#{@test_response_1.folder_id}"
		}
		canned_response   = RSpec.configuration.account.canned_responses.find_by_id(@test_response_1.id)
		access_visibility = RSpec.configuration.account.user_accesses.find_by_accessible_id(@test_response_1.id)
		canned_response.title.should eql("Updated Canned_Responses #{@now}")
		canned_response.content_html.should eql("Updated DESCRIPTION: New Canned_Responses Hepler")
		access_visibility.visibility.should eql 2
		access_visibility.group_id.should_not be_nil
	end

	it "should not update a Canned Responses with empty title" do
		get :edit, :folder_id => @test_response_1.folder_id,:id => @test_response_1.id
		response.body.should =~ /#{@test_response_1.title}/
		put :update, {
			:id => @test_response_1.id,
			:admin_canned_responses_response => {:title => "",
				:content_html => "Updated Canned_Responses without title",
				:visibility => {:user_id => RSpec.configuration.agent.id, 
								:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents], 
								:group_id => @group.id}
			},
			:new_folder_id => @folder_id,
			:folder_id => "#{@test_response_1.folder_id}"
		}
		canned_response = RSpec.configuration.account.canned_responses.find_by_id(@test_response_1.id)
		canned_response.title.should eql("Updated Canned_Responses #{@now}")
		canned_response.title.should_not eql ""
		canned_response.content_html.should_not eql("Updated Canned_Responses without title")
	end

	it "should update the folder of Canned Responses" do
		put :update_folder, :ids => ["#{@test_response_1.id}","#{@test_response_2.id}"], :move_folder_id => @test_cr_folder_1.id, :folder_id => @folder_id
		canned_response_1 = RSpec.configuration.account.canned_responses.find_by_id(@test_response_1.id)
		canned_response_2 = RSpec.configuration.account.canned_responses.find_by_id(@test_response_2.id)
		canned_response_1.folder_id.should eql(@test_cr_folder_1.id)
		canned_response_2.folder_id.should eql(@test_cr_folder_1.id)
	end

	it "should delete multiple Canned Responses" do
		delete :delete_multiple, :ids => ["#{@test_response_1.id}"]
		canned_response = RSpec.configuration.account.canned_responses.find_by_id(@test_response_1.id)
		canned_response.should be_nil
	end

	it "should delete shared attachment" do
		now = (Time.now.to_f*1000).to_i
		canned_response = create_response( {:title => "Recent Canned_Responses #{now}",:content_html => Faker::Lorem.paragraph,
											:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
											:attachments => { :resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png'), 
																:description => Faker::Lorem.characters(10) }
											})
		canned_response.shared_attachments.first.should_not be_nil
		put :update, {
			:id => canned_response.id,
			:admin_canned_responses_response => {
				:title => "Canned Response without attachment",
				:content_html => canned_response.content_html,
				:visibility => {:user_id => @agent.id, 
								:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents], 
								:group_id => @group.id}
			},
			:remove_attachments => ["#{@account.attachments.last.id}"],
			:new_folder_id => @folder_id,
			:folder_id => "#{canned_response.folder_id}"
		}
		canned_response.reload
		canned_response.title.should eql("Canned Response without attachment")
		canned_response.shared_attachments.first.should be_nil
	end
end
