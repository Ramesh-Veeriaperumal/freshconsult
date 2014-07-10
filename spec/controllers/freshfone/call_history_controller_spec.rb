require 'spec_helper'

describe Freshfone::CallHistoryController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    create_freshfone_call
    @request.host = @account.full_domain
    log_in(@agent)
  end

  it 'should get all calls for the default number' do
    freshfone_number = @account.all_freshfone_numbers.first(:order => "deleted ASC")
    freshfone_call = freshfone_number.freshfone_calls.roots.filter(:filter => "Freshfone::Filters::CallFilter").first
    @account.freshfone_calls.create(  :freshfone_number_id => freshfone_number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,
                                      :params => { :CallSid => "CA9cdcef5973752a0895f598a3413a88d5" } )

    get :index
    assigns[:all_freshfone_numbers].first.number.should be_eql(freshfone_number.number)
    assigns[:calls].first.call_sid.should be_eql(freshfone_call.call_sid)
    response.should render_template("freshfone/call_history/index.html.erb")
  end

  it 'should return no results in search for calls made yesterday' do
    get :custom_search, { "wf_order"=>"created_at", "wf_order_type"=>"desc", 
                          "page"=>"1", "number_id"=>@number.id, "wf_c0"=>"created_at", 
                          "wf_o0"=>"is_greater_than", "wf_v0_0"=>"yesterday" }
    assigns[:calls].should be_empty
  end

  it 'should return valid results in search for calls made today' do
    get :custom_search, { "wf_order"=>"created_at", "wf_order_type"=>"desc", 
                          "page"=>"1", "number_id"=>@number.id, "wf_c0"=>"created_at", 
                          "wf_o0"=>"is_greater_than", "wf_v0_0"=>"today" }
    assigns[:calls].should_not be_empty
  end

  it 'should not return any children for a non transferred call' do
    get :children, {"id" => @freshfone_call.id, "number_id" => @number.id}
    assigns[:calls].should be_empty
  end

  it 'should return valid children for a transferred call' do
    create_call_family
    get :children, {"id" => @parent_call, "number_id" => @number.id}
    assigns[:parent_call].should_not be_blank
    assigns[:calls].should_not be_empty
    assigns[:calls].count.should == 1
  end

  it 'should get recent calls' do
    get :recent_calls
    assigns[:calls].should_not be_empty
    response.should render_template('freshfone/call_history/recent_calls.rjs')
  end

end