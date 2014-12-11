require 'spec_helper'

describe Helpdesk::CannedResponses::ResponsesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @now = (Time.now.to_f*1000).to_i
    @group = create_group(@account, {:name => "Response grp #{@now}"})
    @group_new = create_group(@account, {:name => "Response new grp #{@now}"})
    @folder_id = @account.canned_response_folders.default_folder.last.id
    @pfolder_id = @account.canned_response_folders.personal_folder.first.id
    file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
    # Create canned responses
    @test_response_1 = create_response( {:title => "New Canned_Responses Hepler",:content_html => "DESCRIPTION: New Canned_Responses Hepler",
                                         :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
                                         :attachments => {:resource => file, :description => "" } })
    @test_response_2 = create_response( {:title => "New Canned_Responses Hepler #{@now}",:content_html => "DESCRIPTION: New Canned_Responses Hepler #{@now}",
                                         :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]} )
    @personal_response_1 = create_response( {:title => "New Canned_Responses Hepler1 #{@now}",:content_html => "DESCRIPTION: New Canned_Responses Hepler #{@now}",
                                             :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],:folder_id=>@pfolder_id})
    @personal_response_2 = create_response({:title => "New Canned_Responses #{@now}",:content_html => Faker::Lorem.paragraph,
                                            :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                                            :attachments => { :resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png'),
                                                              :description => Faker::Lorem.characters(10) },:folder_id=>@pfolder_id
                                            })

    @test_cr_folder_1 = create_cr_folder({:name => "New CR Folder Helper #{@now}"})
  end

  before(:each) do
    @request.env['HTTP_REFERER'] = '/helpdesk/canned_responses/folders'
    login_admin
    stub_s3_writes
  end

  after(:all) do
    @test_response_2.destroy
    @personal_response_1.destroy
    @personal_response_2.destroy
    @test_cr_folder_1.destroy
  end

  it "should create a new Canned Responses" do
    get :new, :folder_id => @test_response_1.folder_id
    response.should render_template("helpdesk/canned_responses/responses/new")
    post :create, { :admin_canned_responses_response => {:title => "New Canned_Responses #{@now}",
                                                         :content_html => Faker::Lorem.paragraph,
                                                         :visibility => {:user_id => @agent.id,
                                                                         :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                                                                         :group_id => @group.id}
                                                         },
                    :new_folder_id => @folder_id, :folder_id => @folder_id
                    }
    canned_response = @account.canned_responses.find_by_title("New Canned_Responses #{@now}")
    user_access = @account.user_accesses.find_by_accessible_id(canned_response.id)
    canned_response.should_not be_nil
    canned_response.folder_id.should eql @folder_id
    user_access.should_not be_nil
    user_access.group_id.should eql @group.id
    helpdesk_access = @account.accesses.find_by_accessible_id(canned_response.id)
    helpdesk_access.should_not be_nil
    helpdesk_access.groups.map{|group| group.id}.should eql [*@group.id]
    helpdesk_access.users.should eql []
  end

  it "should create a Canned Responses with attachment" do
    post :create, {:admin_canned_responses_response => {:title => "Canned Response with attachment",
                                                        :content_html => Faker::Lorem.paragraph,
                                                        :attachments => [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')}],
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
    helpdesk_access = @account.accesses.find_by_accessible_id(cr_attachment.id)
    helpdesk_access.should_not be_nil
    @account.attachments.last(:conditions=>["content_file_name = ? and attachable_type = ?", "image4kb.png", "Account"]).should_not be_nil
    cr_attachment.shared_attachments.first.should_not be_nil
  end

  it "should not create a new Canned Responses without a title" do
    get :new, :folder_id => @test_response_1.folder_id
    response.should render_template("helpdesk/canned_responses/responses/new")
    post :create, { :admin_canned_responses_response =>{:title => "",
                                                        :content_html => "New Canned_Responses without title",
                                                        :visibility => {:user_id => @agent.id,
                                                                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
                                                                        :group_id => @group.id}
                                                        },
                    :new_folder_id => @folder_id, :folder_id => @folder_id
                    }
    canned_response = @account.canned_responses.find_by_content_html("New Canned_Responses without title")
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
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                        :group_id => @group.id}
      },
      :new_folder_id => @folder_id,
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response   = @account.canned_responses.find_by_id(@test_response_1.id)
    access_visibility = @account.user_accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Updated Canned_Responses #{@now}")
    canned_response.content_html.should eql("Updated DESCRIPTION: New Canned_Responses Hepler")
    access_visibility.visibility.should eql 2
    access_visibility.group_id.should_not be_nil
    helpdesk_access_visibility = @account.accesses.find_by_accessible_id(@test_response_1.id)
    helpdesk_access_visibility.access_type.should eql 2
    helpdesk_access_visibility.groups.map{|group| group.id}.should eql [*@group.id]
    helpdesk_access_visibility.groups.should_not eql []
    helpdesk_access_visibility.users.should eql []
  end

  it "should not update a Canned Responses with empty title" do
    get :edit, :folder_id => @test_response_1.folder_id,:id => @test_response_1.id
    response.body.should =~ /#{@test_response_1.title}/
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {:title => "",
                                           :content_html => "Updated Canned_Responses without title",
                                           :visibility => {:user_id => @agent.id,
                                                           :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                                                           :group_id => @group.id}
                                           },
      :new_folder_id => @folder_id,
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    canned_response.title.should eql("Updated Canned_Responses #{@now}")
    canned_response.title.should_not eql ""
    canned_response.content_html.should_not eql("Updated Canned_Responses without title")
  end

  it "should update a Canned Response visibility from Group to All Agents" do
    get :edit, :folder_id => @test_response_1.folder_id, :id => @test_response_1.id
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {
        :title => "Update Canned_Response visibility to All Agents at #{@now}",
        :content_html => "Updated Description: Group to All Agents",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
                        :group_id => @group.id}
      },
      :new_folder_id => "#{@test_response_1.folder_id}",
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    helpdesk_access_visibility = @account.accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Update Canned_Response visibility to All Agents at #{@now}")
    canned_response.content_html.should eql("Updated Description: Group to All Agents")
    helpdesk_access_visibility.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
    helpdesk_access_visibility.groups.should eql []
    helpdesk_access_visibility.users.should eql []
  end

  it "should update a Canned Response visibility from All to All Agents" do
    get :edit, :folder_id => @test_response_1.folder_id, :id => @test_response_1.id
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {
        :title => "Update Canned_Response visibility to All Agents at #{@now}",
        :content_html => "Updated Description: All to All Agents",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
                        :group_id => @group.id}
      },
      :new_folder_id => "#{@test_response_1.folder_id}",
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    helpdesk_access_visibility = @account.accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Update Canned_Response visibility to All Agents at #{@now}")
    canned_response.content_html.should eql("Updated Description: All to All Agents")
    helpdesk_access_visibility.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
    helpdesk_access_visibility.groups.should eql []
    helpdesk_access_visibility.users.should eql []
  end

  it "should update a Canned Response visibility from All Agents to Myself" do
    get :edit, :folder_id => @test_response_1.folder_id, :id => @test_response_1.id
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {
        :title => "Update Canned_Response visibility to Myself at #{@now}",
        :content_html => "Updated Description: All Agents to Myself",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                        :group_id => @group.id}
      },
      :new_folder_id => "#{@test_response_1.folder_id}",
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    helpdesk_access_visibility = @account.accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Update Canned_Response visibility to Myself at #{@now}")
    canned_response.content_html.should eql("Updated Description: All Agents to Myself")
    helpdesk_access_visibility.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    helpdesk_access_visibility.groups.map{|group| group.id}.should eql []
    helpdesk_access_visibility.users.map{|user| user.id}.should eql [*@agent.id]
  end

  it "should update a Canned Response visibility from Myself to Myself" do
    get :edit, :folder_id => @test_response_1.folder_id, :id => @test_response_1.id
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {
        :title => "Update Canned_Response visibility to Myself at #{@now}",
        :content_html => "Updated Description: Myself to Myself",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                        :group_id => @group.id}
      },
      :new_folder_id => "#{@test_response_1.folder_id}",
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    helpdesk_access_visibility = @account.accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Update Canned_Response visibility to Myself at #{@now}")
    canned_response.content_html.should eql("Updated Description: Myself to Myself")
    helpdesk_access_visibility.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    helpdesk_access_visibility.groups.map{|group| group.id}.should eql []
    helpdesk_access_visibility.users.map{|user| user.id}.should eql [*@agent.id]
  end

  it "should update a Canned Response visibility from Myself to Group" do
    get :edit, :folder_id => @test_response_1.folder_id, :id => @test_response_1.id
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {
        :title => "Update Canned_Response visibility to Group at #{@now}",
        :content_html => "Updated Description: Myself to Group",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                        :group_id => @group.id}
      },
      :new_folder_id => "#{@test_response_1.folder_id}",
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    helpdesk_access_visibility = @account.accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Update Canned_Response visibility to Group at #{@now}")
    canned_response.content_html.should eql("Updated Description: Myself to Group")
    helpdesk_access_visibility.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
    helpdesk_access_visibility.groups.map{|group| group.id}.should eql [*@group.id]
    helpdesk_access_visibility.users.map{|user| user.id}.should eql []
  end

  it "should update a Canned Response visibility from Group to New Group" do
    get :edit, :folder_id => @test_response_1.folder_id, :id => @test_response_1.id
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {
        :title => "Update Canned_Response visibility to Group at #{@now}",
        :content_html => "Updated Description: Group to New Group",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                        :group_id => @group_new.id}
      },
      :new_folder_id => "#{@test_response_1.folder_id}",
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    helpdesk_access_visibility = @account.accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Update Canned_Response visibility to Group at #{@now}")
    canned_response.content_html.should eql("Updated Description: Group to New Group")
    helpdesk_access_visibility.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
    helpdesk_access_visibility.groups.map{|group| group.id}.should eql [*@group_new.id]
    helpdesk_access_visibility.users.map{|user| user.id}.should eql []
  end

  it "should update a Canned Response visibility from Group to Myself" do
    get :edit, :folder_id => @test_response_1.folder_id, :id => @test_response_1.id
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {
        :title => "Update Canned_Response visibility to Myself at #{@now}",
        :content_html => "Updated Description: Group to Myself",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                        :group_id => @group.id}
      },
      :new_folder_id => "#{@test_response_1.folder_id}",
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    helpdesk_access_visibility = @account.accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Update Canned_Response visibility to Myself at #{@now}")
    canned_response.content_html.should eql("Updated Description: Group to Myself")
    helpdesk_access_visibility.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    helpdesk_access_visibility.groups.map{|group| group.id}.should eql []
    helpdesk_access_visibility.users.map{|user| user.id}.should eql [*@agent.id]
  end

  it "should update a Canned Response visibility from Myself to All" do
    get :edit, :folder_id => @test_response_1.folder_id, :id => @test_response_1.id
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {
        :title => "Update Canned_Response visibility to All at #{@now}",
        :content_html => "Updated Description: Myself to All",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
                        :group_id => @group.id}
      },
      :new_folder_id => "#{@test_response_1.folder_id}",
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    helpdesk_access_visibility = @account.accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Update Canned_Response visibility to All at #{@now}")
    canned_response.content_html.should eql("Updated Description: Myself to All")
    helpdesk_access_visibility.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
    helpdesk_access_visibility.groups.map{|group| group.id}.should eql []
    helpdesk_access_visibility.users.map{|user| user.id}.should eql []
  end

  it "should update a Canned Response visibility from All to Group" do
    get :edit, :folder_id => @test_response_1.folder_id, :id => @test_response_1.id
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {
        :title => "Update Canned_Response visibility to Group at #{@now}",
        :content_html => "Updated Description: All to Group",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                        :group_id => @group.id}
      },
      :new_folder_id => "#{@test_response_1.folder_id}",
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    helpdesk_access_visibility = @account.accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Update Canned_Response visibility to Group at #{@now}")
    canned_response.content_html.should eql("Updated Description: All to Group")
    helpdesk_access_visibility.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
    helpdesk_access_visibility.groups.map{|group| group.id}.should eql [*@group.id]
    helpdesk_access_visibility.users.map{|user| user.id}.should eql []
  end

  it "should not move response to other folder if name already excisted" do
    test_response= create_response({:title => @test_response_2.title,:content_html => Faker::Lorem.paragraph,
                                    :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                                    :attachments => { :resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png'),
                                                      :description => Faker::Lorem.characters(10) },:folder_id=>@test_cr_folder_1.id
                                    })
    put :update_folder, :ids => ["#{@test_response_1.id}","#{@test_response_2.id}"], :move_folder_id => @test_cr_folder_1.id, :folder_id => @folder_id

    canned_response_1 = @account.canned_responses.find_by_id(@test_response_1.id)
    canned_response_2 = @account.canned_responses.find_by_id(@test_response_2.id)
    canned_response_2.folder_id.should eql(@test_response_2.folder_id)
    canned_response_1.folder_id.should eql(@test_cr_folder_1.id)
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

  #if visibility is My self, responses should created in personal folder

  it "should create a new Canned Responses in personal folder" do
    get :new, :folder_id => @test_response_1.folder_id
    response.should render_template("helpdesk/canned_responses/responses/new")
    title = "New Canned_Responses12 #{@now}"
    post :create, {
      :admin_canned_responses_response => {
        :title => title,
        :content_html => Faker::Lorem.paragraph,
        :visibility => {
          :user_id => @agent.id,
          :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
        }
      },
      :new_folder_id => @folder_id, :folder_id => @folder_id
    }
    canned_response = @account.canned_responses.find_by_title(title)
    user_access = @account.user_accesses.find_by_accessible_id(canned_response.id)
    canned_response.should_not be_nil
    canned_response.folder_id.should eql @pfolder_id
    user_access.visibility.should eql 3
  end

  #if visibility selected as My self, responses should updated in personal folder

  it "should update visibility of Canned Responses when moved to personal folder " do
    test_response= create_response({:title => @test_response_2.title,:content_html => Faker::Lorem.paragraph,
                                    :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                                    :attachments => { :resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png'),
                                                      :description => Faker::Lorem.characters(10) },:folder_id=>@test_cr_folder_1.id
                                    })
    put :update, {
      :id => test_response.id,
      :admin_canned_responses_response => {
        :title => "title",
        :content_html => "Updated DESCRIPTION: New Canned_Responses Hepler",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
                        }
      },
      :new_folder_id => test_response.folder_id,
      :folder_id => test_response.folder_id
    }
    canned_response   = @account.canned_responses.find_by_id(test_response.id)
    access_visibility = @account.user_accesses.find_by_accessible_id(test_response.id)
    canned_response.folder_id.should eql @pfolder_id
    canned_response.content_html.should eql("Updated DESCRIPTION: New Canned_Responses Hepler")
    access_visibility.visibility.should eql 3
  end

  # default visiblity check for personal folder -new response
  it "should create a Canned Responses in personal folder " do
    get :new, :folder_id => @pfolder_id
    response.should render_template("helpdesk/canned_responses/responses/new")
    (assigns(:ca_response).accessible.visibility).should eql 3
  end

  # person folder -new response
  it "should create new response in personal folder" do
    get :new, :folder_id => @pfolder_id
    response.should render_template("helpdesk/canned_responses/responses/new")
    title="New Canned_Responses45 #{@now}"
    post :create, { :admin_canned_responses_response =>{:title => title,
                                                        :content_html => Faker::Lorem.paragraph,
                                                        :visibility => {:user_id => @agent.id,
                                                                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                                                                        }
                                                        },
                    :new_folder_id => @pfolder_id, :folder_id => @pfolder_id
                    }
    canned_response = @account.canned_responses.find_by_title(title)
    user_access = @account.user_accesses.find_by_accessible_id(canned_response.id)
    canned_response.should_not be_nil
    canned_response.folder_id.should eql @pfolder_id
    user_access.should_not be_nil
    user_access.visibility.should eql 3
  end

  # title uniqueness check - while creating new response

  it "should not create Canned Responses if title present in folder" do
    get :new, :folder_id => @test_response_1.folder_id
    response.should render_template("helpdesk/canned_responses/responses/new")
    post :create, { :admin_canned_responses_response =>{:title => @test_response_2.title,
                                                        :content_html => Faker::Lorem.paragraph,
                                                        :visibility => {:user_id => @agent.id,
                                                                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                                                                        :group_id => @group.id}
                                                        },
                    :new_folder_id => @folder_id, :folder_id => @folder_id
                    }
    response.body.should =~ /Title already exists/
  end

  # title uniqueness check - while updating response

  it "should update visibility of Canned Responses when title present in personal folder " do
    test_response= create_response({:title => "Test response",:content_html => Faker::Lorem.paragraph,
                                    :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],:folder_id=>@test_cr_folder_1.id
                                    })
    put :update, {
      :id => test_response.id,
      :admin_canned_responses_response => {
        :title => @personal_response_1.title,
        :content_html => "Updated DESCRIPTION: New Canned_Responses Hepler",
        :visibility => {:user_id => @agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
                        }
      },
      :new_folder_id => test_response.folder_id,
      :folder_id =>test_response.folder_id
    }
    canned_response   = @account.canned_responses.find_by_id(test_response.id)
    access_visibility = @account.user_accesses.find_by_accessible_id(test_response.id)
    canned_response.title.should eql(@personal_response_1.title)
    canned_response.folder_id.should eql @personal_response_1.folder_id
    access_visibility.visibility.should eql 3
  end

  # Bulk move cases starts from here


  # personal to other folders - visibility update

  it "should update visibility before moving response from personal to other" do
    test_response= create_response({:title => @personal_response_1.title,:content_html => Faker::Lorem.paragraph,
                                    :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                                    :attachments => { :resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png'),
                                                      :description => Faker::Lorem.characters(10) },:folder_id=>@test_cr_folder_1.id
                                    })
    put :update_folder, :ids => ["#{@personal_response_1.id}","#{@personal_response_2.id}"], :move_folder_id => @test_cr_folder_1.id, :folder_id => @pfolder_id,:visibility=>1

    canned_response_1 = @account.canned_responses.find_by_id(@personal_response_1.id)
    canned_response_2 = @account.canned_responses.find_by_id(@personal_response_2.id)
    access_visibility = @account.user_accesses.find_by_accessible_id(@personal_response_2.id)
    canned_response_1.folder_id.should eql(@personal_response_1.folder_id)
    canned_response_2.folder_id.should eql(@test_cr_folder_1.id)
    access_visibility.visibility.should eql 1
  end

  # other folders to personal - visibility update

  it "should update visibility before moving response from personal to other" do
    test_response= create_response({:title => "New response",:content_html => Faker::Lorem.paragraph,
                                    :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
                                    :attachments => { :resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png'),
                                                      :description => Faker::Lorem.characters(10) },:folder_id=>@folder_id
                                    })
    put :update_folder, :ids => [test_response.id], :move_folder_id => @pfolder_id, :folder_id => @folder_id
    canned_response_2 = @account.canned_responses.find_by_id(test_response.id)
    access_visibility = @account.user_accesses.find_by_accessible_id(test_response.id)
    canned_response_2.folder_id.should eql(@pfolder_id)
    access_visibility.visibility.should eql 3
  end

  it "should delete multiple Canned Responses" do
    new_response = @account.canned_responses.find_by_title("New Canned_Responses #{@now}")
    ids = ["#{@test_response_1.id}","#{new_response.id}"]
    delete :delete_multiple, :ids => ids
    ids.each do |id|
      @account.canned_responses.find_by_id(id).should be_nil
    end
  end


end
