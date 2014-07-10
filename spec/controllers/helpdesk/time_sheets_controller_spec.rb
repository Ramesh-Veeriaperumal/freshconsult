require 'spec_helper'
include Redis::TicketsRedis
include Redis::RedisKeys

describe Helpdesk::TimeSheetsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Time sheets"}))
    @group = @account.groups.first
  end

  before(:each) do
    log_in(@agent)
  end

  it "should create a new timer" do
    now = (Time.now.to_f*1000).to_i
    post :create, { :time_entry => { :workable_id => @test_ticket.id,
                                     :user_id => @agent.id,
                                     :hhmm => "1:30",
                                     :billable => "1",
                                     :executed_at => "02/19/2014",
                                     :timer_running => 1,
                                     :note => "#{now}"},
                    :_ => "",
                    :ticket_id => @test_ticket.display_id
                  }
    @test_timesheet = @account.time_sheets.find_by_workable_id(@test_ticket.id)
    @test_timesheet.note.should be_eql("#{now}")
  end

  it "should edit a timer" do
    now = (Time.now.to_f*1000).to_i
    test_ticket1 = create_ticket({ :status => 2 }, @group)
    time_sheet = Factory.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => test_ticket1.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :note => "Note for edit")
    time_sheet.save
    @account.time_sheets.find_by_note("Note for Edit").should be_an_instance_of(Helpdesk::TimeSheet)
    put :update, { :time_entry => {  :user_id => @agent.id,
                                     :hhmm => "2:30",
                                     :billable => "1",
                                     :executed_at => "02/25/2014",
                                     :note => "#{now}"},
                    :_ => "",
                    :id => time_sheet.id
                  }
    @account.time_sheets.find_by_note("#{now}").should be_an_instance_of(Helpdesk::TimeSheet)
  end

  it "should start a timer" do
    test_ticket2 = create_ticket({ :status => 2 }, @group)
    time_sheet = Factory.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => test_ticket2.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :timer_running => false,
                                            :note => "Stop Timer")
    time_sheet.save
    put :toggle_timer, :id => time_sheet.id
    test_ticket2.time_sheets.first.timer_running.should be_true
  end

  it "should stop a timer" do
    test_ticket3 = create_ticket({ :status => 2 }, @group)
    time_sheet = Factory.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => test_ticket3.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :timer_running => true,
                                            :note => "Stop Timer")
    time_sheet.save
    put :toggle_timer, :id => time_sheet.id
    test_ticket3.time_sheets.first.timer_running.should be_false
  end

  it "should delete a time sheet entry" do
    test_ticket4 = create_ticket({ :status => 2 }, @group)
    time_sheet = Factory.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => test_ticket4.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :note => "Note for delete")
    time_sheet.save
    delete :destroy, :id => time_sheet.id
    test_ticket4.time_sheets.first.should be_nil
  end
end
