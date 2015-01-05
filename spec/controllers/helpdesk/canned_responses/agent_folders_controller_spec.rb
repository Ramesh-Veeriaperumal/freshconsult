require 'spec_helper'

describe Helpdesk::CannedResponses::FoldersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @now = Time.now.to_i
    @pfolder = @account.canned_response_folders.personal_folder.first
    @test_role = create_role({:name => "Second: New role test #{@now}",
                              :privilege_list => ["manage_tickets", "edit_ticket_properties", "view_solutions", "manage_solutions",
                                                  "view_forums", "0", "0", "0", "0",
                                                  "", "0", "0", "0", "0"]} )
    @new_agent = add_test_agent(@account,{:role => @test_role.id})
  end

  before(:each) do
    log_in(@new_agent)
  end

  it "should go to the folder index page" do
    get :index
    response.should render_template("helpdesk/canned_responses/folders/index.html.erb")
    response.body.should =~ /Personal/
  end

  it "should render create new folder template" do
    xhr :get, :new
    response.status == 200
  end

  it "should not create a new folder" do
    post :create, { :admin_canned_responses_folder => {:name => "New CR Folder #{@now}"} }
    @account.canned_response_folders.find_by_name("New CR Folder #{@now}").should be_nil
  end

  it "should not update a Personal folder" do
    begin
      put :update, { :id => @pfolder.id,
                     :admin_canned_responses_folder => { :name => "Updated General #{@now}" }
                     }
    rescue Exception => e
      folder = @account.canned_response_folders.find(@pfolder.id)
      folder.name.should_not eql "Updated General #{@now}"
    end
  end

  it "should not delete a Personal folder" do
    begin
      delete :destroy, :id => @pfolder.id
    rescue Exception => e
      @account.canned_response_folders.find(@pfolder.id).should_not be_nil
    end
  end
end
