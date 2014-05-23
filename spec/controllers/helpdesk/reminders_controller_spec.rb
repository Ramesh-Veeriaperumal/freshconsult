require 'spec_helper'
include Redis::TicketsRedis
include Redis::RedisKeys

describe Helpdesk::RemindersController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Reminders"}))
    @group = @account.groups.first
  end

  before(:each) do
    log_in(@user)
  end

  it "should create a new reminder" do
    test_body = Faker::Lorem.sentence(3)
    post :create, { :source => "ticket_view", 
                    :helpdesk_reminder => { :body => test_body }, 
                    :_ => "",  
                    :ticket_id => @test_ticket.display_id
                  }
    p "@test_ticket.reminders.first.body"
    p @test_ticket.reminders.first.body              
    @test_ticket.reminders.first.body.should be_eql(test_body)
  end

  it "should strike off a to-do entry" do
    reminder = Factory.build(:reminder, :user_id => @user.id, 
                                        :ticket_id => @test_ticket.id, 
                                        :account_id => @account.id)
    reminder.save
    put :complete, { :source => "ticket_view", :id => @test_ticket.reminders.first.id }
    @test_ticket.reminders.first.deleted.should be_true
  end

  it "should delete a reminder" do
    reminder = Factory.build(:reminder, :user_id => @user.id, 
                                        :ticket_id => @test_ticket.id, 
                                        :account_id => @account.id)
    reminder.save
    delete :destroy, :id => reminder.id
    @test_ticket.reminders.find_by_id(reminder.id).should be_nil
  end
end