require 'spec_helper'

describe Helpdesk::CannedResponses::ResponsesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @now = (Time.now.to_f*1000).to_i
    @test_role = create_role({:name => "Second: New role test #{@now}",
                              :privilege_list => ["manage_tickets", "edit_ticket_properties", "view_solutions", "manage_solutions",
                                                  "view_forums", "0", "0", "0", "0",
                                                  "", "0", "0", "0", "0"]} )
    @new_agent = add_test_agent(@account,{:role => @test_role.id})
    @pfolder_id = @account.canned_response_folders.personal_folder.first.id
    stub_s3_writes
    file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
    # Create canned responses
    @test_response_1 = create_response( {:title => "New Canned_Responses Hepler1 #{@now}",:content_html => "DESCRIPTION: New Canned_Responses Hepler #{@now}",
                                         :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],:user_id=>@new_agent.id,:folder_id=>@pfolder_id})

  end

  before(:each) do
    @request.env['HTTP_REFERER'] = '/helpdesk/canned_responses/folders'
    stub_s3_writes
    log_in(@new_agent)
    stub_s3_writes
  end

  it "should create a new Canned Responses" do
    get :new, :folder_id =>@pfolder_id
    response.should render_template("helpdesk/canned_responses/responses/new")
    post :create, { :admin_canned_responses_response =>{:title => "New Canned_Responses #{@now}",
                                                        :content_html => Faker::Lorem.paragraph,
                                                        :visibility => {:user_id => @new_agent.id,
                                                                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
                                                                        }
                                                        },
                    :new_folder_id => @pfolder_id, :folder_id => @pfolder_id
                    }
    canned_response = @account.canned_responses.find_by_title("New Canned_Responses #{@now}")
    user_access = @account.user_accesses.find_by_accessible_id(canned_response.id)
    canned_response.should_not be_nil
    canned_response.folder_id.should eql @pfolder_id
    user_access.should_not be_nil
    user_access.visibility.should eql 3
  end

  it "should create a Canned Responses with attachment" do
    post :create, {:admin_canned_responses_response => {:title => "Canned Response with attachment",
                                                        :content_html => Faker::Lorem.paragraph,
                                                        :attachments => [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')}],
                                                        :visibility => {:user_id => @new_agent.id,
                                                                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                                                                        }
                                                        },
                   :new_folder_id => @pfolder_id, :folder_id => @pfolder_id
                   }
    cr_attachment = @account.canned_responses.find_by_title("Canned Response with attachment")
    cr_attachment.should_not be_nil
    user_access = @account.user_accesses.find_by_accessible_id(cr_attachment.id)
    user_access.should_not be_nil
    @account.attachments.last(:conditions=>["content_file_name = ? and attachable_type = ?", "image4kb.png", "Account"]).should_not be_nil
    cr_attachment.shared_attachments.first.should_not be_nil
  end

  it "should not create a new Canned Responses without a title" do
    post :create, { :admin_canned_responses_response =>{:title => "",
                                                        :content_html => "New Canned_Responses without title",
                                                        :visibility => {:user_id => @new_agent.id,
                                                                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                                                                        }
                                                        },
                    :new_folder_id => @pfolder_id, :folder_id => @pfolder_id
                    }
    canned_response = @account.canned_responses.find_by_content_html("New Canned_Responses without title")
    canned_response.should be_nil
  end

  it "should show a Canned Responses" do
    get :show, :folder_id => @pfolder_id,:id => @pfolder_id
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
        :visibility => {:user_id => @new_agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
                        }
      },
      :new_folder_id => @pfolder_id,
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response   = @account.canned_responses.find_by_id(@test_response_1.id)
    access_visibility = @account.user_accesses.find_by_accessible_id(@test_response_1.id)
    canned_response.title.should eql("Updated Canned_Responses #{@now}")
    canned_response.content_html.should eql("Updated DESCRIPTION: New Canned_Responses Hepler")
    access_visibility.visibility.should eql 3
  end

  it "should not update a Canned Responses with empty title" do
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {:title => "",
                                           :content_html => "Updated Canned_Responses without title",
                                           :visibility => {:user_id => @new_agent.id,
                                                           :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                                                           }
                                           },
      :new_folder_id => @pfolder_id,
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
    canned_response.title.should eql("Updated Canned_Responses #{@now}")
    canned_response.title.should_not eql ""
    canned_response.content_html.should_not eql("Updated Canned_Responses without title")
  end

  it "should delete shared attachment" do
    now = (Time.now.to_f*1000).to_i
    canned_response = create_response( {:title => "Recent Canned_Responses #{now}",:content_html => Faker::Lorem.paragraph,
                                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                                        :attachments => { :resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png'),
                                                          :description => Faker::Lorem.characters(10) }
                                        })
    canned_response.shared_attachments.first.should_not be_nil
    put :update, {
      :id => canned_response.id,
      :admin_canned_responses_response => {
        :title => "Canned Response without attachment",
        :content_html => canned_response.content_html,
        :visibility => {:user_id => @new_agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                        }
      },
      :remove_attachments => ["#{@account.attachments.last.id}"],
      :new_folder_id => @pfolder_id,
      :folder_id => "#{canned_response.folder_id}"
    }
    canned_response.reload
    canned_response.title.should eql("Canned Response without attachment")
    canned_response.shared_attachments.first.should be_nil
  end

  # default visiblity check for personal folder -new response
  it "should create a Canned Responses in personal folder " do
    get :new, :folder_id => @pfolder_id
    response.should render_template("helpdesk/canned_responses/responses/new")
    (assigns(:ca_response).accessible.visibility).should eql 3
  end

  #if visibility other than My self, responses should created in personal folder

  it "should create a new Canned Responses in personal folder" do
    post :create, { :admin_canned_responses_response =>{:title => "New Canned_Responses #{@now}",
                                                        :content_html => Faker::Lorem.paragraph,
                                                        :visibility => {:user_id => @new_agent.id,
                                                                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
                                                                        }
                                                        },
                    :new_folder_id => @pfolder_id, :folder_id => @pfolder_id
                    }
    canned_response = @account.canned_responses.find_by_title("New Canned_Responses #{@now}")
    user_access = @account.user_accesses.find_by_accessible_id(canned_response.id)
    canned_response.should_not be_nil
    canned_response.folder_id.should eql @pfolder_id
    user_access.visibility.should eql 3
  end

  # no title uniqueness check - while creating new response

  it "should create response if title already present" do
    test_response=create_response( {:title => "New Canned_Responses Hepler1 #{@now}",:content_html => "DESCRIPTION: New Canned_Responses Hepler #{@now}",
                                    :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],:user_id=>@new_agent.id,:folder_id=>@pfolder_id})
    post :create, { :admin_canned_responses_response =>{:title => test_response.title,
                                                        :content_html => Faker::Lorem.paragraph,
                                                        :visibility => {:user_id => @new_agent.id,
                                                                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                                                                        }
                                                        },
                    :new_folder_id => @pfolder_id, :folder_id => @pfolder_id
                    }
    canned_response = @account.canned_responses.find_by_title(test_response.title)
    user_access = @account.user_accesses.find_by_accessible_id(canned_response.id)
    canned_response.should_not be_nil
    canned_response.folder_id.should eql @pfolder_id
    user_access.visibility.should eql 3
  end

  # no title uniqueness check - while updating response

  it "should update response if title exists " do
    test_response=create_response( {:title => "New Canned_Responses Hepler2 #{@now}",:content_html => "DESCRIPTION: New Canned_Responses Hepler #{@now}",
                                    :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],:user_id=>@new_agent.id,:folder_id=>@pfolder_id})
    put :update, {
      :id => @test_response_1.id,
      :admin_canned_responses_response => {
        :title => test_response.title,
        :content_html => "Updated DESCRIPTION: New Canned_Responses Hepler",
        :visibility => {:user_id => @new_agent.id,
                        :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
                        }
      },
      :new_folder_id => "#{@test_response_1.folder_id}",
      :folder_id => "#{@test_response_1.folder_id}"
    }
    canned_response   = @account.canned_responses.find_by_id(@test_response_1.id)
    canned_response.title.should eql(test_response.title)
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
