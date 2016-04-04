require 'spec_helper'

describe Helpdesk::SubscriptionsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "subscription"}))
    @group = @account.groups.first
  end

  before(:each) do
    login_admin
  end

  it "should render the list of watchers of a ticket" do
    ticket = create_ticket
    subscription = FactoryGirl.build(:subscription, :account_id => @account.id,
                                                :ticket_id => ticket.id,
                                                :user_id => @agent.id)
    subscription.save
    get :index, :ticket_id => ticket.display_id
    response.should render_template "helpdesk/subscriptions/_ticket_watchers"
  end

  it "should add current user as a watcher" do
    test_user = add_agent(@account, { :name => Faker::Name.name, 
                                      :email => Faker::Internet.email, 
                                      :active => 1, 
                                      :role => 1, 
                                      :agent => 1,
                                      :ticket_permission => 1,
                                      :role_ids => ["#{@account.roles.first.id}"] })
    post :create_watchers, :ticket_id => @test_ticket.display_id, :user_id => test_user.id
    @test_ticket.subscriptions.last.ticket_id.should be_eql(@test_ticket.id)
    Delayed::Job.last.handler.should include("notify_new_watcher")
  end

  it "should unwatch a ticket" do
    ticket = create_ticket
    subscription = FactoryGirl.build(:subscription, :account_id => @account.id,
                                                :ticket_id => ticket.id,
                                                :user_id => @agent.id)
    subscription.save
    get :unsubscribe, :ticket_id => ticket.display_id
    ticket.reload
    ticket.subscriptions.first.should be_nil
  end

  it "should unwatch multiple tickets" do
    3.times do |i|
      instance_variable_set("@ticket_#{i+1}", create_ticket)
      instance_variable_set("@subscription_#{i+1}", FactoryGirl.build(:subscription, 
                                                                :account_id => @account.id,
                                                                :ticket_id => instance_variable_get("@ticket_#{i+1}").id,
                                                                :user_id => @agent.id).save)
    end
    delete :unwatch_multiple, :ticket_id => "multiple", :ids => [ @ticket_1.display_id, 
                                                                  @ticket_2.display_id,
                                                                  @ticket_3.display_id,]
    @ticket_1.subscriptions.first.should be_nil
    @ticket_2.subscriptions.first.should be_nil
    @ticket_3.subscriptions.first.should be_nil
  end
end
