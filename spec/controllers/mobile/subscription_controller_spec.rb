require 'spec_helper'

describe Helpdesk::SubscriptionsController do
  self.use_transactional_fixtures = false

  before(:all) do
    @group = @account.groups.first
  end

  before(:each) do
    api_login
  end

  it "should get all the watchers" do
    test_user = add_agent(@account, {:name => Faker::Name.name, 
                        :email => Faker::Internet.email, 
                        :active => 1, 
                        :role => 1, 
                        :agent => 1,
                        :ticket_permission => 1,
                        :role_ids => ["#{@account.roles.first.id}"] })
    test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "subscription"}))
    test_ticket.subscriptions.build(:user_id => test_user.id)
    test_ticket.save!
    get :index, { :format => "json", :ticket_id => test_ticket.display_id }
    json_response.should be_an_instance_of(Array) 
    json_response[0].should be_eql(test_user.id)
  end

  it "should unwatch a ticket" do
    test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "subscription"}))
    test_ticket.subscriptions.build(:user_id => @agent.id)
    test_ticket.save!
    delete :unwatch, { :format => "json", :ticket_id => test_ticket.display_id }
    json_response.should include("success")
    json_response["success"].should be true
  end

  it "should create watcher" do
    test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "subscription"}))
    post :create_watchers, {:format => "json", :ticket_id => test_ticket.display_id, :user_id => @agent.id}
    json_response.should include("success")
    json_response["success"].should be true
  end
end