require 'spec_helper'

describe Admin::CannedResponses::FoldersController do
	integrate_views
    setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
	    @cr_folder_1 = create_cr_folder({:name => "CR Folder"})
	    @cr_folder_2 = create_cr_folder({:name => "Additional CR Folder"})
	    @folder = Admin::CannedResponses::Folder.find_by_is_default(true)
	end

	before(:each) do
	    log_in(@user)
	end

	it "should go to the folder index page" do
	    get :index
	    response.should render_template("admin/canned_responses/folders/index")
	    response.body.should =~ /General/
	end

	it "should create a new folder" do
		@now = (Time.now.to_f*1000).to_i
		get :new
		response.should_not be_nil
	    post :create, { :admin_canned_responses_folder => {:name => "New CR Folder #{@now}"} }
	    folder = Admin::CannedResponses::Folder.find_by_name("New CR Folder #{@now}")
	    folder.should_not be_nil
	end

	it "should not create a new folder with minimum 3 characters" do
	    post :create, { :admin_canned_responses_folder => {:name => "cr"} }
	    folder = Admin::CannedResponses::Folder.find_by_name("cr")
	    folder.should be_nil
	end

	it "should update a folder" do
		get :edit
		response.should_not be_nil
		put :update, { :id => @cr_folder_1.id, 
                   :admin_canned_responses_folder => { :name => "Updated CR Folder #{@now}" }
                  }
        folder = Admin::CannedResponses::Folder.find_by_name("Updated CR Folder #{@now}")
	    folder.should_not be_nil
	end

	it "should contain minimum 3 characters for folder name" do
		put :update, { :id => @cr_folder_1.id, 
                   :admin_canned_responses_folder => { :name => "CR" }
                  }
        folder = Admin::CannedResponses::Folder.find_by_id(@cr_folder_1.id)
	    folder.name.should_not eql "CR"
	end

	it "should view a folder" do
		get :show, :id => @cr_folder_2.id
		response.body.should =~ /Additional CR Folder/
	end

	it "should delete a folder" do
    	delete :destroy, :id => @cr_folder_1.id
    	folder = Admin::CannedResponses::Folder.find_by_id(@cr_folder_1.id)
    	folder.should be_nil
    end

    it "should not update a General folder" do
    	begin
	    	put :update, { :id => @folder.id, 
	                   :admin_canned_responses_folder => { :name => "Updated General #{@now}" }
	                  }
        rescue Exception => e
        	folder = Admin::CannedResponses::Folder.find_by_id(@folder.id)
            folder.name.should_not eql "Updated General #{@now}"
        end
    end

    it "should not delete a General folder" do
    	begin
	    	delete :destroy, :id => @folder.id
        rescue Exception => e
        	folder = Admin::CannedResponses::Folder.find_by_id(@folder.id)
            folder.should_not be_nil
        end
    end
end