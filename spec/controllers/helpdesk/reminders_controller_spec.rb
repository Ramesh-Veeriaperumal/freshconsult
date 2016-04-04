require 'spec_helper'
RSpec.configure do |c|
  c.include Redis::TicketsRedis
  c.include Redis::RedisKeys
end

RSpec.describe Helpdesk::RemindersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Reminders"}))
    @group = @account.groups.first
  end

  before(:each) do
    log_in(@agent)
  end

  it "should create a new reminder" do
    test_body = Faker::Lorem.sentence(3)
    post :create, { :source => "ticket_view",
                    :helpdesk_reminder => { :body => test_body },
                    :_ => "",
                    :ticket_id => @test_ticket.display_id
                  }
    @test_ticket.reminders.first.body.should be_eql(test_body)
  end

  it "should create a new reminder - Mobile format" do
    new_ticket = create_ticket({:status => 2})
    test_body = Faker::Lorem.sentence(3)
    post :create, { :source => "ticket_view",
                    :helpdesk_reminder => { :body => test_body },
                    :_ => "",
                    :ticket_id => new_ticket.display_id,
                    :format => 'mobile'
                  }
    new_ticket.reminders.first.body.should eql(test_body)
  end

  it "should not create a new reminder without reminder_body" do
    post :create, { :source => "ticket_view",
                    :helpdesk_reminder => { :body => "" },
                    :_ => "",
                    :ticket_id => @test_ticket.display_id
                  }
    response.should redirect_to "/sessions/new"
  end

  it "should strike off a to-do entry" do
    reminder = FactoryGirl.build(:reminder, :user_id => @agent.id,
                                        :ticket_id => @test_ticket.id,
                                        :account_id => @account.id)
    reminder.save
    put :complete, { :source => "ticket_view", :id => @test_ticket.reminders.first.id }
    @test_ticket.reminders.first.deleted.should be_truthy
  end

  it "should restore a to-do entry" do
    put :restore, { :source => "ticket_view", :id => @test_ticket.reminders.first.id }
    @test_ticket.reminders.first.deleted.should be_falsey
  end

  it "should delete a reminder" do
    reminder = FactoryGirl.build(:reminder, :user_id => @agent.id,
                                        :ticket_id => @test_ticket.id,
                                        :account_id => @account.id)
    reminder.save
    delete :destroy, :id => reminder.id
    @test_ticket.reminders.find_by_id(reminder.id).should be_nil
  end
end
