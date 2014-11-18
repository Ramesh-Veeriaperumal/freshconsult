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
    @group = @account.groups.first
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
                                     :user_id => @agent.id,
                                     :hhmm => "1:30",
                                     :billable => "1",
                                     :executed_at => DateTime.now.strftime("%d %b, %Y"),
                                     :timer_running => 1,
                                     :note => "#{now}"},
                    :_ => "",
                    :ticket_id => @test_ticket.display_id
                  }
    @test_timesheet = @account.time_sheets.find_by_workable_id(@test_ticket.id)
    @test_timesheet.note.should be_eql("#{now}")
  end

  it "should render the edit timesheet form" do
    ticket = create_ticket
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => ticket.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :note => "")
    time_sheet.save
    get :edit, :ticket_id => ticket.display_id, :id => time_sheet.id
    response.should render_template "helpdesk/time_sheets/edit"
  end

  it "should edit a timer" do
    now = (Time.now.to_f*1000).to_i
    test_ticket1 = create_ticket({ :status => 2 }, @group)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => @agent.id,
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
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => test_ticket2.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :timer_running => false,
                                            :note => "Stop Timer")
    time_sheet.save
    put :toggle_timer, :id => time_sheet.id
    test_ticket2.time_sheets.first.timer_running.should be_truthy
  end

  it "should stop a timer" do
    test_ticket3 = create_ticket({ :status => 2 }, @group)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => test_ticket3.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :timer_running => true,
                                            :note => "Stop Timer")
    time_sheet.save
    put :toggle_timer, :id => time_sheet.id
    test_ticket3.time_sheets.first.timer_running.should be_falsey
  end

  it "should delete a time sheet entry" do
    test_ticket4 = create_ticket({ :status => 2 }, @group)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => test_ticket4.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :note => "Note for delete")
    time_sheet.save
    delete :destroy, :id => time_sheet.id
    test_ticket4.time_sheets.first.should be_nil
  end

  it "should sysnc workflowmax" do
    @new_installed_app = FactoryGirl.build(:installed_application, :application_id => 8,
                                              :account_id => @account.id,
                                              :configs => { :inputs => { "title" => "Workflow MAX", 
                                                            "api_key" => "14C10292983D48CE86E1AA1FE0F8DDFE", 
                                                            "account_key" => "F6B597FC29604DDE9A77A20BA9A2CE86",
                                                            "workflow_max_note" => "Freshdesk Ticket # {{ticket.id}}" }
                                                          }
                                              )
    @new_installed_app.save(validate: false)
    test_ticket3 = create_ticket({ :status => 2 }, @group)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => test_ticket3.id,
                                            :workable_type => "Helpdesk::Ticket",
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :timer_running => true,
                                            :note => "Stop Timer")
    time_sheet.save
    integrated_resources = FactoryGirl.build(:integrated_resource,
                                            :installed_application_id => @new_installed_app.id,
                                            :account_id => @account.id,
                                            :remote_integratable_id => 37707917,
                                            :local_integratable_id => time_sheet.id,
                                            :local_integratable_type => "Helpdesk::TimeSheet")
    integrated_resources.save!
    integrated_resources.local_integratable_type = "Helpdesk::TimeSheet"
    integrated_resources.save!
    put :toggle_timer, :id => time_sheet.id
    put :toggle_timer, :id => time_sheet.id
    test_ticket3.time_sheets.first.timer_running.should be_truthy
  end

  it "should sysnc freshbooks" do
    @new_installed_app = FactoryGirl.build(:installed_application, :application_id => 2,
                                              :account_id => @account.id,
                                              :configs => { :inputs => { "title" => "Freshbooks", 
                                                            "api_url" => "https://fresh2027.freshbooks.com/api/2.1/xml-in", 
                                                            "api_key" => "c9b9a1762bf31f12b3eb1ae1fb5bc90f",
                                                            "freshbooks_note" => "Freshdesk Ticket # {{ticket.id}}" }
                                                          }
                                              )
    @new_installed_app.save(validate: false)
    test_ticket3 = create_ticket({ :status => 2 }, @group)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => test_ticket3.id,
                                            :workable_type => "Helpdesk::Ticket",
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :timer_running => true,
                                            :note => "Stop Timer")
    time_sheet.save
    integrated_resources = FactoryGirl.build(:integrated_resource,
                                            :installed_application_id => @new_installed_app.id,
                                            :account_id => @account.id,
                                            :remote_integratable_id => 336848,
                                            :local_integratable_id => time_sheet.id,
                                            :local_integratable_type => "Helpdesk::TimeSheet")
    integrated_resources.save!
    integrated_resources.local_integratable_type = "Helpdesk::TimeSheet"
    integrated_resources.save!
    put :toggle_timer, :id => time_sheet.id
    put :toggle_timer, :id => time_sheet.id
    test_ticket3.time_sheets.first.timer_running.should be_truthy
  end

  it "should sysnc harvest" do
    @new_installed_app = FactoryGirl.build(:installed_application, :application_id => 3,
                                              :account_id => @account.id,
                                              :configs => { :inputs => { "title" => "Harvest", 
                                                            "domain" => "starimpact.harvestapp.com", 
                                                            "harvest_note" => "Freshdesk Ticket # {{ticket.id}}" }
                                                          }
                                              )
    @new_installed_app.save(validate: false)
    user_credentials = FactoryGirl.build(:integration_user_credential,
                                              :account_id => @account.id,
                                              :user_id => @agent.id,
                                              :installed_application_id => @new_installed_app.id,
                                              :auth_info => { :username => "vasanth+01@freshdesk.com",
                                                            :password => "VGVzdGluZ0AxMjM="
                                                          }
                                              )
    user_credentials.save(validate: false)
    test_ticket3 = create_ticket({ :status => 2 }, @group)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => test_ticket3.id,
                                            :workable_type => "Helpdesk::Ticket",
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :timer_running => true,
                                            :note => "Stop Timer")
    time_sheet.save
    integrated_resources = FactoryGirl.build(:integrated_resource,
                                            :installed_application_id => @new_installed_app.id,
                                            :account_id => @account.id,
                                            :remote_integratable_id => 276244281,
                                            :local_integratable_id => time_sheet.id,
                                            :local_integratable_type => "Helpdesk::TimeSheet")
    integrated_resources.save!
    integrated_resources.local_integratable_type = "Helpdesk::TimeSheet"
    integrated_resources.save!
    put :toggle_timer, :id => time_sheet.id
    put :toggle_timer, :id => time_sheet.id
    test_ticket3.time_sheets.first.timer_running.should be_truthy
  end
end
