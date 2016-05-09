require 'spec_helper'

RSpec.describe GroupsController do
  include Redis::RedisKeys
  include Redis::OthersRedis
  
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    Role.add_manage_availability_privilege

    @now = (Time.now.to_f*1000).to_i
    @agent = add_test_agent(@account, {:role => Role.agent.first.id})
    @supervisor = add_test_agent(@account, {:role => Role.supervisor.first.id})
    @agent_list = [@supervisor.id, @agent.id]
    @test_group = create_group(@account, {:name => "Spec Testing Grp Helper #{@now}"})
    @supervisor_group = create_group_with_agents(@account, 
        {:name => "Spec Testing Grp Helper - Supervisor #{@now}", :ticket_assign_type => 0, :agent_list => @agent_list})

    @calendar = FactoryGirl.build(:business_calendars,:name=> "Grp business_calendar", :description=>Faker::Lorem.sentence(2),:account_id=>@account.id)
    @calendar.save(:validate => false)
  end

  describe "Agent" do
    before(:each) do
      log_in(@agent)
    end

   it "should not access index page" do
      get :index
      response.should redirect_to("http://#{@account.full_domain}/support/login")
    end

    it "should not access new page" do
      get :new
      response.should redirect_to("http://#{@account.full_domain}/support/login")
    end
  end

  describe "Supervisor with manage_availability privilege" do
    before(:each) do
      log_in(@supervisor)
    end

    it "should access index page" do
      get :index
      response.should be_success
      response.body.should =~ /Groups/
    end

    it "should not render new page" do
      get :new
      response.should redirect_to("http://#{@account.full_domain}/support/login")
    end

    it "should not delete a  Group" do
      name = "Spec Testing Grp Helper to delete #{@now}"
      group_to_delete = create_group(@account, {:name => name})

      delete :destroy, :id => group_to_delete.id
      @account.groups.find_by_name(name).should_not be_nil
    end

    it "should render edit page of accessible group" do
      get :edit, :id => @supervisor_group.id
      response.body.should =~ /"#{@supervisor_group.name}"/
    end

    it "should not render edit page of inaccessible group" do
      get :edit, :id => @test_group.id
      response.should redirect_to("http://#{@account.full_domain}/support/login")
    end

    it "should not update name of the accessible Group" do
      new_name = "updating the name #{@now}"
      new_description = "updating the description #{@now}"
      temp_agent = add_test_agent(@account)

      put :update, {
        :id => @supervisor_group.id,
        :group => {:name => new_name,
          :description => new_description, 
          :business_calendar => @calendar.id,
          :agent_list => "#{temp_agent.id}"
        }
      }

      @supervisor_group.reload

      @supervisor_group.name.should_not eql(new_name)
      @supervisor_group.description.should_not eql(new_description)
      @supervisor_group.agent_groups.pluck(:id).should_not eql([temp_agent.id])
    end

    it "should change ticket_assign_type " do
      new_ticket_assign_type = (@supervisor_group.ticket_assign_type == 1 ? 0 : 1)
      put :update, {
        :id => @supervisor_group.id,
        :group => { :ticket_assign_type => new_ticket_assign_type }
      }

      @supervisor_group.reload
      @supervisor_group.ticket_assign_type == new_ticket_assign_type
    end

    it "should toggle agents availability" do
      put :update, {
        :id => @supervisor_group.id,
        :group => { :ticket_assign_type => 1,
            :toggle_availability => 1}
      }

      @supervisor_group.reload
      @supervisor_group.ticket_assign_type  == 1
      @supervisor_group.toggle_availability == 1
    end
  end

  describe "Supervisor without manage_availability privilege" do
    before(:all) do
      Role.remove_manage_availability_privilege @account
      @account.reload
      @supervisor.reload
    end

    after(:all) do
      Role.add_manage_availability_privilege @account
    end

    before(:each) do
      log_in(@supervisor)
    end

    it "should not access index page" do
      get :index
      response.should redirect_to("http://#{@account.full_domain}/support/login")
    end

  end

end
