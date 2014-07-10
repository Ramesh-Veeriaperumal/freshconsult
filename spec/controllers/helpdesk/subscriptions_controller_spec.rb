require 'spec_helper'

describe Helpdesk::SubscriptionsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "subscription"}))
    @group = @account.groups.first
  end

  before(:each) do
    login_admin
  end

  it "should add current user as a watcher" do
    test_user = add_agent(@account, {:name => Faker::Name.name, 
                        :email => Faker::Internet.email, 
                        :active => 1, 
                        :role => 1, 
                        :agent => 1,
                        :ticket_permission => 1,
                        :role_ids => ["#{@account.roles.first.id}"] })
    post :create_watchers, :ticket_id => @test_ticket.display_id, :user_id => test_user.id
    @test_ticket.subscriptions.last.ticket_id.should be_eql(@test_ticket.id)
    Delayed::Job.last.handler.should include("deliver_notify_new_watcher")
  end
end