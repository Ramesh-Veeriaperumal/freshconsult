require 'spec_helper'

RSpec.configure do |c|
  c.include Redis::TicketsRedis
  c.include Redis::RedisKeys
end

RSpec.describe Helpdesk::TimeSheetsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Time sheets"}))
    @group = RSpec.configuration.account.groups.first
  end

  before(:each) do
    log_in(@agent)
  end

  it "should render the index page" do
    get :index, :ticket_id => @test_ticket.display_id
    response.should render_template("helpdesk/time_sheets/index")
  end

  it "should render the add-time form" do
    ticket = create_ticket
    get :new, :ticket_id => ticket.display_id
    response.should render_template "helpdesk/time_sheets/new"
  end

  it "should create a new timer" do
    now = (Time.now.to_f*1000).to_i
    post :create, { :time_entry => { :workable_id => @test_ticket.id,
                                     :user_id => RSpec.configuration.agent.id,
                                     :hhmm => "1:30",
                                     :billable => "1",
                                     :executed_at => DateTime.now.strftime("%d %b, %Y"),
                                     :timer_running => 1,
                                     :note => "#{now}"},
                    :_ => "",
                    :ticket_id => @test_ticket.display_id
                  }
    @test_timesheet = RSpec.configuration.account.time_sheets.find_by_workable_id(@test_ticket.id)
    @test_timesheet.note.should be_eql("#{now}")
  end

  it "should render the edit timesheet form" do
    ticket = create_ticket
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => RSpec.configuration.agent.id,
                                            :workable_id => ticket.id,
                                            :account_id => RSpec.configuration.account.id,
                                            :billable => 1,
                                            :note => "")
    time_sheet.save
    get :edit, :ticket_id => ticket.display_id, :id => time_sheet.id
    response.should render_template "helpdesk/time_sheets/edit"
  end

  it "should edit a timer" do
    now = (Time.now.to_f*1000).to_i
    test_ticket1 = create_ticket({ :status => 2 }, @group)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => RSpec.configuration.agent.id,
                                            :workable_id => test_ticket1.id,
                                            :account_id => RSpec.configuration.account.id,
                                            :billable => 1,
                                            :note => "Note for edit")
    time_sheet.save
    RSpec.configuration.account.time_sheets.find_by_note("Note for Edit").should be_an_instance_of(Helpdesk::TimeSheet)
    put :update, { :time_entry => {  :user_id => RSpec.configuration.agent.id,
                                     :hhmm => "2:30",
                                     :billable => "1",
                                     :executed_at => "02/25/2014",
                                     :note => "#{now}"},
                    :_ => "",
                    :id => time_sheet.id
                  }
    RSpec.configuration.account.time_sheets.find_by_note("#{now}").should be_an_instance_of(Helpdesk::TimeSheet)
  end

  it "should start a timer" do
    test_ticket2 = create_ticket({ :status => 2 }, @group)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => RSpec.configuration.agent.id,
                                            :workable_id => test_ticket2.id,
                                            :account_id => RSpec.configuration.account.id,
                                            :billable => 1,
                                            :timer_running => false,
                                            :note => "Stop Timer")
    time_sheet.save
    put :toggle_timer, :id => time_sheet.id
    test_ticket2.time_sheets.first.timer_running.should be_truthy
  end

  it "should stop a timer" do
    test_ticket3 = create_ticket({ :status => 2 }, @group)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => RSpec.configuration.agent.id,
                                            :workable_id => test_ticket3.id,
                                            :account_id => RSpec.configuration.account.id,
                                            :billable => 1,
                                            :timer_running => true,
                                            :note => "Stop Timer")
    time_sheet.save
    put :toggle_timer, :id => time_sheet.id
    test_ticket3.time_sheets.first.timer_running.should be_falsey
  end

  it "should delete a time sheet entry" do
    test_ticket4 = create_ticket({ :status => 2 }, @group)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => RSpec.configuration.agent.id,
                                            :workable_id => test_ticket4.id,
                                            :account_id => RSpec.configuration.account.id,
                                            :billable => 1,
                                            :note => "Note for delete")
    time_sheet.save
    delete :destroy, :id => time_sheet.id
    test_ticket4.time_sheets.first.should be_nil
  end
end
