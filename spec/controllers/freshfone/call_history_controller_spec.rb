require 'spec_helper'

RSpec.describe Freshfone::CallHistoryController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    create_freshfone_call
    @request.host = @account.full_domain
    log_in(@agent)
  end

  it 'should get all calls for the default number' do
    @account.freshfone_calls.destroy_all
    call_sid = "CA9cdcef5973752a0895f598a3413a88d5"
    freshfone_number = @account.all_freshfone_numbers.first(:order => "deleted ASC")
    @account.reload
    @account.freshfone_calls.create(  :freshfone_number_id => freshfone_number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,
                                      :params => { :CallSid => call_sid } )

    get :index
    assigns[:all_freshfone_numbers].first.number.should be_eql(freshfone_number.number)
    assigns[:calls].first.call_sid.should eql call_sid
    response.should render_template("freshfone/call_history/index")
  end

  it 'should return no results in search for calls made yesterday' do
    get :custom_search, { "wf_order"=>"created_at", "wf_order_type"=>"desc", 
                          "page"=>"1", 
                          :data_hash => '[{"condition": "created_at","operator": "is_in_the_range","value": "' + Date.yesterday.inspect + '"}]',
                          "number_id"=>@number.id }
    assigns[:calls].should be_empty
  end

  it 'should return valid results in search for calls made today' do
    get :custom_search, { "wf_order"=>"created_at", "wf_order_type"=>"desc", 
                          "page"=>"1", 
                          :data_hash => '[{"condition": "created_at","operator": "is_in_the_range","value": "' + Date.today.inspect + '"}]',
                          "number_id"=>@number.id }
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
    @request.env["HTTP_ACCEPT"] = "application/javascript"
    get :recent_calls
    assigns[:calls].should_not be_empty
    response.should render_template('freshfone/call_history/recent_calls')
  end

end