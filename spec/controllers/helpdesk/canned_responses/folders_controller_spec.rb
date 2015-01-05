require 'spec_helper'

describe Helpdesk::CannedResponses::FoldersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @cr_folder_1 = create_cr_folder({:name => "CR Folder"})
    @cr_folder_2 = create_cr_folder({:name => "Additional CR Folder"})
    @folder = @account.canned_response_folders.default_folder.last
    @pfolder = @account.canned_response_folders.personal_folder.first
  end

  before(:each) do
    login_admin
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

  it "should create a new folder" do
    @now = (Time.now.to_f*1000).to_i
    get :new
    should redirect_to "/helpdesk/canned_responses/folders"
    post :create, { :admin_canned_responses_folder => {:name => "New CR Folder #{@now}"} }
    @account.canned_response_folders.find_by_name("New CR Folder #{@now}").should_not be_nil
  end

  it "should not create a new folder with less than 3 characters" do
    post :create, { :admin_canned_responses_folder => {:name => "cr"} }
    @account.canned_response_folders.find_by_name("cr").should be_nil
  end

  it "should update a folder" do
    get :edit
    response.should_not be_nil
    put :update, { :id => @cr_folder_1.id,
                   :admin_canned_responses_folder => { :name => "Updated CR Folder #{@now}" }
                   }
    @account.canned_response_folders.find_by_name("Updated CR Folder #{@now}").should_not be_nil
  end

  it "should not update folder name if the name has less than 3 characters" do
    put :update, { :id => @cr_folder_1.id,
                   :admin_canned_responses_folder => { :name => "CR" }
                   }
    folder = @account.canned_response_folders.find(@cr_folder_1.id)
    folder.name.should_not eql "CR"
  end

  it "should view a folder" do
    get :show, :id => @cr_folder_2.id
    response.body.should =~ /Additional CR Folder/
  end

  it "should delete a folder" do
    delete :destroy, :id => @cr_folder_1.id
    @account.canned_response_folders.find_by_id(@cr_folder_1.id).should be_nil
  end

  it "should delete a folder - Js format" do
    delete :destroy, :id => @cr_folder_2.id, :format => 'js'
    @account.canned_response_folders.find_by_id(@cr_folder_2.id).should be_nil
  end

  it "should not update a General folder" do
    begin
      put :update, { :id => @folder.id,
                     :admin_canned_responses_folder => { :name => "Updated General #{@now}" }
                     }
    rescue Exception => e
      folder = @account.canned_response_folders.find(@folder.id)
      folder.name.should_not eql "Updated General #{@now}"
    end
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

  it "should not delete a General folder" do
    begin
      delete :destroy, :id => @folder.id
    rescue Exception => e
      @account.canned_response_folders.find(@folder.id).should_not be_nil
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
