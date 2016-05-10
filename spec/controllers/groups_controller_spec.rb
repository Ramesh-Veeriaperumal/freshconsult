require 'spec_helper'

RSpec.describe GroupsController do
  include Redis::RedisKeys
  include Redis::OthersRedis

  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @now = (Time.now.to_f*1000).to_i
    @user_1 = add_test_agent(@account)
    @test_group = create_group(@account, {:name => "Spec Testing Grp Helper"})
    @calendar = FactoryGirl.build(:business_calendars,:name=> "Grp business_calendar", :description=>Faker::Lorem.sentence(2),:account_id=>@account.id)
    @calendar.save(:validate => false)
    @agent_list = "#{@user_1},#{@agent}"
  end

  before(:each) do
    log_in(@agent)
  end

  after(:all) do
    @test_group.destroy
    @calendar.destroy
  end

  it "should go to the Groups index page" do
    get :index
    response.body.should =~ /Product Management/
    response.should be_success
  end

  it "should render new page" do
    get :new
    response.body.should =~ /New Group/
    response.should be_success
  end

  it "should create a new Group" do
    post :create, { :group => { :name => "Spec Testing Grp #{@now}", :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
                  :agent_list => "#{@agent_list}", :ticket_assign_type=> 1, :assign_time => "1800", :escalate_to => @user_1.id
                  }
    }
    @account.groups.find_by_name("Spec Testing Grp #{@now}").should_not be_nil
  end

  it "should not create a Group without the name" do
    post :create, { :group => { :name => "", :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
                  :agent_list => "#{@agent_list}", :ticket_assign_type=> 1,
                  :assign_time => "1800", :escalate_to => @agent.id
                  }
    }
    response.body.should =~ /Name can&#x27;t be blank/
  end

  it "should edit the Group" do
    get :edit, :id => @test_group.id
    response.body.should =~ /"#{@test_group.name}"/
  end

  it "should show the Group" do
    get :show, :id => @test_group.id
    response.body.should =~ /redirected/
  end

  it "should update the Group" do
    put :update, {
      :id => @test_group.id,
      :group => {:name => "Updated: Spec Testing Grp #{@now}",
        :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
        :agent_list => "#{@agent_list}",
        :ticket_assign_type=> 0,
        :toggle_availability=> 0,
        :assign_time => "2500", :escalate_to => @agent.id
      }
    }
    @test_group.reload
    @test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
    @test_group.escalate_to.should eql(@agent.id)
    @test_group.ticket_assign_type.should eql 0
    @test_group.toggle_availability.should eql false
  end

  it "should set toggle availability only if round robin is enabled" do
    put :update, {
      :id => @test_group.id,
      :group => {:name => "Updated: Spec Testing Grp #{@now}",
        :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
        :added_list => "",
        :removed_list => "", 
        :ticket_assign_type=> 0,
        :toggle_availability=> 1,
        :assign_time => "2500", :escalate_to => @agent.id
      }
    }

    @test_group.reload
    @test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
    @test_group.escalate_to.should eql(@agent.id)
    @test_group.ticket_assign_type.should eql 0
    @test_group.toggle_availability.should eql false
  end

  it "should add agents to the group" do
    existing_user_ids = @test_group.agent_groups.pluck(:user_id)
    new_user_ids = existing_user_ids + [@agent.id , @user_1.id]

    put :update, {
      :id => @test_group.id,
      :group => {:name => "Updated: Spec Testing Grp #{@now}",
        :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
        :agent_list => "#{new_user_ids.join(",")}",
        :ticket_assign_type=> 1,
        :assign_time => "2500", :escalate_to => @agent.id
      }
    }
    @test_group.reload
    @test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
    @test_group.escalate_to.should eql(@agent.id)
    @test_group.ticket_assign_type.should eql 1

    agents_in_group = @test_group.agent_groups.pluck(:user_id)
    (new_user_ids.sort == agents_in_group.sort).should be true
  end

  it "should add agents to the group with non-round robin but not create the list" do
    existing_user_ids = @test_group.agent_groups.pluck(:user_id)
    new_user_ids = existing_user_ids + [@agent.id , @user_1.id]
    put :update, {
      :id => @test_group.id,
      :group => {:name => "Updated: Spec Testing Grp #{@now}",
        :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
        :agent_list => "#{new_user_ids.join(",")}",
        :ticket_assign_type=> 0,
        :assign_time => "2500", :escalate_to => @agent.id
      }
    }
    @test_group.reload
    @test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
    @test_group.escalate_to.should eql(@agent.id)
    @test_group.ticket_assign_type.should eql 0
    value = get_others_redis_list(@test_group.round_robin_key)
    value.should be_empty
  end

  it "should add agents to the group with round robin and create the list" do
    existing_user_ids = @test_group.agent_groups.pluck(:user_id)
    new_user_ids = existing_user_ids + [@agent.id , @user_1.id]
    put :update, {
      :id => @test_group.id,
      :group => {:name => "Updated: Spec Testing Grp #{@now}",
        :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
        :agent_list => "#{new_user_ids.join(",")}",
        :ticket_assign_type=> 1,
        :assign_time => "2500", :escalate_to => @agent.id
      }
    }
    @test_group.reload
    @test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
    @test_group.escalate_to.should eql(@agent.id)
    @test_group.ticket_assign_type.should eql 1
    user_ids = @test_group.agent_groups.available_agents.pluck(:user_id).compact
    set_others_redis_lpush(@test_group.round_robin_key, user_ids) if user_ids.any?
    value = get_others_redis_rpoplpush(@test_group.round_robin_key, @test_group.round_robin_key)
    value.should_not be_nil
  end

  it "should remove agents from the group" do
    new_user_ids = existing_user_ids = @test_group.agent_groups.pluck(:user_id)
    new_user_ids.delete(@agent.id)
    put :update, {
      :id => @test_group.id,
      :group => {:name => "Updated: Spec Testing Grp #{@now}",
        :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
        :agent_list => "#{new_user_ids.join(",")}",
        :ticket_assign_type=> 0,
        :assign_time => "2500", :escalate_to => @agent.id
      }
    }
    @test_group.reload
    @test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
    @test_group.escalate_to.should eql(@agent.id)
    @test_group.ticket_assign_type.should eql 0
    agents_in_group = @test_group.agent_groups.pluck(:user_id)
    agents_in_group.include?(@agent.id).should be false
    value = get_others_redis_list(@test_group.round_robin_key)
    value.should be_empty
  end

  it "should not update the Group without a name" do
    put :update, {
      :id => @test_group.id,
      :group => {:name => "",
        :description => "Updated Description: Spec Testing Grp", :business_calendar => @calendar.id,
        :agent_list => "#{@agent_list}",
        :ticket_assign_type=> 0,
        :assign_time => "2500", :escalate_to => @agent.id
      }
    }
    @test_group.reload
    @test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
    @test_group.name.should_not eql ""
    @test_group.escalate_to.should eql(@agent.id)
    @test_group.description.should_not eql "Updated Description: Spec Testing Grp"
  end

  it "should not show roundrobin settings for non roundrobin accounts" do
    @account.features.round_robin.destroy
    @account.reload
    get :edit, :id => @test_group.id
    response.body.should_not =~ /Automatic ticket assignment/
    @account.features.round_robin.create
    @account.reload
  end

  it "should add manage_availability privilege for supervisor and above" do
    get :enable_roundrobin_v2
    @account.roles.supervisor.first.privilege?(:manage_availability).should be true
  end

  it "should delete a Group" do
    name = "Spec Testing Grp Helper to delete"
    @group_to_delete = create_group(@account, {:name => name})
    group = @account.groups.find_by_name(name)
    delete :destroy, :id => group.id
    @account.groups.find_by_id(group.id).should be_nil
  end

end
