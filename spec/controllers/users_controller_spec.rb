require 'spec_helper'

describe UsersController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@user = add_new_user(@account)
		@user_agent = add_test_agent(@account)
		@new_user = FactoryGirl.build(:user, :avatar_attributes => { :content => fixture_file_upload('files/image4kb.png', 
                                        'image/png')},
                                    :name => "user with profile image",
                                    :email => Faker::Internet.email,
                                    :time_zone => "Chennai",
                                    :delta => 1,
                                    :deleted => 0,
                                    :blocked => 0,
                                    :customer_id => nil,
                                    :language => "en")
	    @new_user.save
	end

	before(:each) do
		login_admin
		stub_s3_writes
	end

	it "should list all users" do
		get :index
		response.body.should =~ /redirected/
	end

	it "should redirect to new user" do
		get :new
		response.body.should =~ /redirected/
	end

	it "should create a new user" do
	    test_email = Faker::Internet.email
	    post :create, :user => { :name => Faker::Name.name, :email => test_email , :time_zone => "Chennai", :language => "en" }
	    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    end

	it "should edit a user" do
		get :edit, :id => @user.id
		response.body.should =~ /redirected/
	end

	it "should update a user" do
		now = (Time.now.to_f*1000).to_i
		put :update,{:id => @user.id,
					 :user => { :name => "user with profile image #{now}", :email => @user.email , :time_zone => @user.time_zone, 
								:language => @user.language }
		}
		session["flash"][:notice].should eql "The user has been updated."
		@account.users.find_by_name("user with profile image #{now}").should be_an_instance_of(User)
	end

	it "should view a user" do
		get :show, :id => @user.id
    response.should redirect_to :controller => 'contacts', 
                                :action => 'show', :id => @user.id
	end

	it "should view a user_agent" do
		get :show, :id => @user_agent.id
    response.should redirect_to :controller => 'agents', 
                                :action => 'show', :id => @user_agent.agent.id
	end

	it "should display profile image" do
        @new_user.should be_an_instance_of(User)
        get :profile_image, :id => @new_user.id
        response.body.should =~ /redirected/
	end

	it "should assume_identity for a user" do
		get :assume_identity, :id => @new_user.id
		session[:flash][:notice].should eql "You've assumed your identity as #{@new_user.name}."
		response.should redirect_to "/"
	end

	it "should not assume_identity for a user" do
		user = add_test_agent(@account)
		log_in(user)
		get :assume_identity, :id => user.id
		session[:flash][:notice].should eql "You are not allowed to assume this user."
		response.should redirect_to "/"
	end

	it "should not revert_identity to original user" do
		get :revert_identity 
		session[:flash][:error].should eql "Sorry, we couldn't find your original user."
		response.should redirect_to '/'
	end

	it "should delete profile_image of a user" do
		put :delete_avatar, :id => @new_user.id
	    @new_user.reload
	    @new_user.avatar.should eql nil
	    response.body.should =~ /success/
	end

	it "should block the user" do
		user = add_new_user(@account)
		put :block, :id => user.id #TODO-RAILS3 change the same in views
		user.reload
		user.deleted.should be true
		session[:flash][:notice].should eql "Following contact(s) (#{user.name}) have been blocked"
	end
end