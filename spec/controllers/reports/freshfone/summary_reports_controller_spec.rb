require 'spec_helper'

describe Reports::Freshfone::SummaryReportsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @account.update_attributes(:full_domain => "http://play.ngrok.com")
    create_test_freshfone_account
    create_freshfone_call
    @request.host = @account.full_domain
    log_in(@agent)
  end

  it "should show the summary of calls" do
    number = @account.freshfone_numbers.first
    start_date = Date.today.prev_month.strftime('%d %b, %Y')
    end_date = Date.today.strftime('%d %b, %Y')
    post :index, {:date_range=>"#{start_date} - #{end_date}", :freshfone_number=>number.id}
    assigns[:calls].should_not be_empty
    assigns[:old_calls].should be_empty
    response.should render_template "reports/freshfone/summary_reports/index"
  end

  it "should generate the summary for the incoming calls criteria" do
    request.env["HTTP_ACCEPT"] = "application/javascript"
    number = @account.freshfone_numbers.first
    start_date = (Date.today-7.day).strftime('%d %b, %Y')
    end_date = Date.today.strftime('%d %b, %Y')
    groups = @account.groups.map(&:id)
    post :generate, {:date_range=>"#{start_date} - #{end_date}", :freshfone_number=>number.id, 
          :call_type=>1}
    assigns[:calls].should_not be_empty
    response.should render_template("reports/freshfone/summary_reports/generate")
  end

  it "should generate the summary for the outgoing calls criteria" do
    request.env["HTTP_ACCEPT"] = "application/javascript"
    number = @account.freshfone_numbers.first
    start_date = (Date.today-7.day).strftime('%d %b, %Y')
    end_date = Date.today.strftime('%d %b, %Y')
    groups = @account.groups.map(&:id)
    post :generate, {:date_range=>"#{start_date} - #{end_date}", :freshfone_number=>number.id, 
          :call_type=>2,:group_id=> groups.first}
    assigns[:calls].should be_empty
    response.should render_template("reports/freshfone/summary_reports/generate")
  end
  
   it "should generate the summary for the incoming calls with unassigned group criteria" do
    request.env["HTTP_ACCEPT"] = "application/javascript"
    number = @account.freshfone_numbers.first
    start_date = (Date.today-7.day).strftime('%d %b, %Y')
    end_date = Date.today.strftime('%d %b, %Y')
    post :generate, {:date_range =>"#{start_date} - #{end_date}", :freshfone_number => number.id, 
          :call_type => 1,:group_id => Reports::FreshfoneReport::UNASSIGNED_GROUP.to_i}
    assigns[:calls].should_not be_empty
    response.should render_template("reports/freshfone/summary_reports/generate")
  end

   it "should generate the summary for the incoming calls for all numbers" do
    start_date = (Date.today-7.day).strftime('%d %b, %Y')
    end_date = Date.today.strftime('%d %b, %Y')
    post :generate, {:date_range =>"#{start_date} - #{end_date}", :freshfone_number => Reports::FreshfoneReport::ALL_NUMBERS, 
          :call_type => 1,:group_id => Reports::FreshfoneReport::UNASSIGNED_GROUP.to_i}
    assigns[:calls].should_not be_empty
    response.should render_template("reports/freshfone/summary_reports/generate.rjs")
  end

   it "should generate the summary for the outgoing calls for all numbers" do
    start_date = (Date.today-7.day).strftime('%d %b, %Y')
    end_date = Date.today.strftime('%d %b, %Y')
    post :generate, {:date_range =>"#{start_date} - #{end_date}", :freshfone_number => Reports::FreshfoneReport::ALL_NUMBERS, 
          :call_type => 2,:group_id => Reports::FreshfoneReport::UNASSIGNED_GROUP.to_i}
    assigns[:calls].should be_empty
    response.should render_template("reports/freshfone/summary_reports/generate.rjs")
  end

  it "should export the data as a csv for the outgoing calls criteria" do
    number = @account.freshfone_numbers.first
    start_date = (Date.today-7.day).strftime('%d %b, %Y')
    end_date = Date.today.strftime('%d %b, %Y')
    post :export_csv, {:date_range=>"#{start_date} - #{end_date}", :freshfone_number=>number.id }
    assigns[:calls].should_not be_empty
    expected = (response.status == 200)
    expected.should be true
  end

end