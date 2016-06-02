require 'spec_helper'

describe Admin::RolesController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@now = (Time.now.to_f*1000).to_i
		@test_role = create_role( { :name => "First: New role test #{@now}", 
									:privilege_list => ["manage_tickets", "edit_ticket_properties", "view_forums", "view_contacts", 
														"view_reports", "", "0", "0", "0", "0" ]} )
		@test_role_1 = create_role({:name => "Second: New role test #{@now}", 
									:privilege_list => ["manage_tickets", "edit_ticket_properties", "view_solutions", "manage_solutions", 
														"view_forums", "manage_forums", "view_contacts", "view_reports", "manage_users", 
														"", "0", "0", "0", "view_admin"]} )
		@new_user = add_test_agent(@account,{:role => @test_role.id})
	end

	before(:each) do
		login_admin
	end

	it "should go to the Roles index page" do
		get :index
		response.body.should =~ /Agent Roles/
		response.should be_success
	end

	it "should go to the new Role" do
		get :new
		response.body.should =~ /New Role/
		response.should be_success
	end

	it "should create a new Role" do
		privileges = [ "manage_tickets", "reply_ticket", "forward_ticket", "view_solutions", "view_forums", 
			"view_contacts", "view_reports", "manage_contacts", "", "0", "0", "0", "0" ] 
		post :create, { :role => {  :name => "Create: New role test #{@now}", :description => Faker::Lorem.paragraph, 
									:privilege_list => privileges
									} 
						}
		new_role = @account.roles.find_by_name("Create: New role test #{@now}")
		new_user = add_test_agent(@account,{:role => new_role.id})
		user_privilege = verify_user_privileges(new_user, privileges)
		user_privilege.should be_truthy
		new_role.should_not be_nil
	end

	it "should not create a new Role without the name" do
		post :create, {:role =>{:name => "", :description => Faker::Lorem.paragraph, 
								:privilege_list => [ "view_forums", "view_contacts", "view_reports", "", "0", "0", "0", "0"] 
								} 
						}
		new_role = @account.roles.find_by_description(Faker::Lorem.paragraph)
		new_role.should be_nil
		response.body.should =~ /New Role/
	end

	it "should edit a Role" do
		get :edit, :id => @test_role.id
		response.body.should =~ /"#{@test_role.name}"/
	end

	it "should show a Role" do
		get :show, :id => @test_role.id
		response.body.should =~ /redirected/
	end

	it "should update the Role" do
		privileges = [ "manage_tickets","forward_ticket", "view_solutions", "manage_solutions", 
			"view_forums", "manage_forums", "view_reports", "manage_users","", "0", "0", "0", "view_admin" ]
		put :update, {
			:id => @test_role.id,
			:role => {:name => "Updated: Roles #{@now}", :description => Faker::Lorem.paragraph,
				:privilege_list => privileges
			}
		}
		@test_role.reload
		@test_role.name.should eql("Updated: Roles #{@now}")
		@new_user.reload
		user_privilege = verify_user_privileges(@new_user, privileges)
		user_privilege.should be_truthy
	end

	it "should not update role without the name" do
		put :update, {
			:id => @test_role.id,
			:role => {:name => "", :description => Faker::Lorem.paragraph,
				:privilege_list => [ "view_forums", "view_contacts", "view_reports", "", "0", "0", "0", "0" ]
			}
		}
		@test_role.reload
		@test_role.name.should eql("Updated: Roles #{@now}")
	end

	it "should not update the default Roles" do
		default_role = @account.roles.find_by_name("Account Administrator")
		put :update, {
			:id => default_role.id,
			:role => {:name => "Updated default_role", :description => Faker::Lorem.paragraph,
				:privilege_list => [ "view_forums", "view_contacts", "view_reports", "", "0", "0", "0", "0" ]
			}
		}
		new_role = @account.roles.find_by_id(default_role.id)
		new_role.name.should_not be_eql("Updated default_role")
		session[:flash][:notice].should eql "You cannot modify default roles"
		response.body.should =~ /redirected/
	end

	it "should not delete the default Roles" do
		default_role = @account.roles.find_by_name("Supervisor")
		delete :destroy, :id => default_role.id
		new_role = @account.roles.find_by_id(default_role.id)
		new_role.should_not be_nil
		session[:flash][:notice].should eql "You cannot modify default roles"
		response.body.should =~ /redirected/
	end

	it "should not delete a Role that is already assigned to a user" do
		delete :destroy, :id => @test_role.id
		session[:flash][:notice].should eql "You cannot delete this role. There are other users are associated with it."
		@test_role.reload
		@test_role.should_not be_nil
	end

	it "should delete a Role" do
		delete :destroy, :id => @test_role_1.id
		new_role = @account.roles.find_by_id(@test_role_1.id)
		new_role.should be_nil
	end

	it "should render the correct user_list json" do
		post :users_list,{ :id => @test_role.id } 
		role = response.body.split(",").second.include?("#{@test_role.id}")
		role.should be_truthy
	end

	it "should not contain account_admin in custom Role" do
		admin_user = @account.users.find_by_email(@account.admin_email)
		@test_role.user_ids.include?(admin_user.id).should_not be_truthy
	end

	it "should not contain account_admin in Supervisor" do
		admin_user = @account.users.find_by_email(@account.admin_email)
		default_role = @account.roles.find_by_name("Supervisor")
		default_role.user_ids.include?(admin_user.id).should_not be_truthy
	end
	
	it "should not allow account_admin to be added to new role" do 
		admin_user = @account.users.find_by_email(@account.admin_email)
		post :create, {:role =>{:name => "new_role_1", :description => Faker::Lorem.paragraph, 
						:privilege_list => [ "view_forums", "view_contacts", "view_reports", "", "0", "0", "0", "0"]}, 
						:add_user_ids => [admin_user.id] 
						}
		new_role_1 = @account.roles.find_by_name("new_role_1")
		new_role_1.user_ids.include?(admin_user.id).should_not be_truthy				
	end

	it "should accept agent addition on creation of new Role" do
		post :create, {:role =>{:name => "new_role", :description => Faker::Lorem.paragraph, 
						:privilege_list => [ "view_forums", "view_contacts", "view_reports", "", "0", "0", "0", "0"]}, 
						:add_user_ids => [@new_user.id] 
						}
		new_role = @account.roles.find_by_name("new_role")
		@new_user.role_ids.include?(new_role.id).should be_truthy
	end

	it "should update agents in roles" do
		@new_user1 = add_test_agent(@account)
		put :update, {
			:id => @test_role.id,
			:role => {:name => "", :description => Faker::Lorem.paragraph,
				:privilege_list => [ "view_forums", "view_contacts", "view_reports", "", "0", "0", "0", "0"]}, :add_user_ids => [@new_user1.id], :delete_user_ids => [@new_user.id]
			}
		@new_user1.role_ids.include?(@test_role.id).should be_truthy
		@new_user.role_ids.include?(@test_role.id).should_not be_truthy
	end
end
