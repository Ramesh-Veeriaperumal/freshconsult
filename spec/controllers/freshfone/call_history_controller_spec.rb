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
    create_online_freshfone_user
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

  it 'should not delete voice recording if the user is not an admin' do
    @freshfone_call.update_attributes!(:recording_url => 
      "http://api.twilio.com/2010-04-01/Accounts/AC9fa514fa8c52a3863a76e2d76efa2b8e/Recordings/REbd383eb591106df8d80bb556d3b6f59e")
    @freshfone_call.create_recording_audio(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                            :description => Faker::Lorem.characters(10), 
                                            :account_id => @account.id)
    controller.class.any_instance.stubs(:privilege?).returns(false)
    delete :destroy_recording,{:id => @freshfone_call.id}
    expect(response.body).to be_empty
    controller.class.any_instance.unstub(:privilege?)
  end

  it 'should delete voice recording if the user is admin' do
    @freshfone_call.update_attributes!(:recording_url => 
      "http://api.twilio.com/2010-04-01/Accounts/AC9fa514fa8c52a3863a76e2d76efa2b8e/Recordings/REbd383eb591106df8d80bb556d3b6f59e")
    @freshfone_call.create_recording_audio(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                            :description => Faker::Lorem.characters(10), 
                                            :account_id => @account.id)
    recording = mock()
    Twilio::REST::Recordings.any_instance.stubs(:get).returns(recording)
    recording.stubs(:delete).returns(true)
    delete :destroy_recording,{:id =>@freshfone_call.id}
    @freshfone_call.reload
    expect(@freshfone_call.recording_audio).to be_nil
    expect(@freshfone_call.recording_url).to be_nil
    expect(@freshfone_call.recording_deleted).to be true
    expect(@freshfone_call.recording_deleted_by).to be_eql(@agent.name)
    expect(response.body).to match(/call-id-#{@freshfone_call.id}/)
    expect(response.body).to match( /Call Recording deleted successfully!/)
    Twilio::REST::Recordings.any_instance.unstub(:get)
  end

  describe "Call History Export Worker" do
    TEST_CALL_TYPE = 1
    TEST_CALL_STATUS = 1
    before :each do
      require 'csv'
      FileUtils.stubs(:rm_f)

      @account.freshfone_calls.destroy_all
      @freshfone_number = @account.all_freshfone_numbers.first(:order => "deleted ASC")
      @account.reload

      @export_params = { 
        :data_hash => '[{"condition": "created_at","operator": "is_in_the_range","value": "' + Date.today.inspect + '"}]',
        :export_to => "csv", :account_id => @account.id, :user_id => @agent.id, :portal_url => @account.full_domain 
      }

      @out_dir   = "#{Rails.root}/tmp/export/#{@account.id}/call_history"
    end

    after :all do
      out_dir = "#{Rails.root}/tmp/export/#{@account.id}/call_history" 
      FileUtils.remove_dir(out_dir, true)
    end

    it 'should export call records successfully' do
      call_sid = "CA9cdcef5973752a0895f598a3413a88d5"
      @account.freshfone_calls.create(  :freshfone_number_id => @freshfone_number.id, 
                                        :call_status => TEST_CALL_STATUS, :call_type => TEST_CALL_TYPE, :agent => @agent,
                                        :params => { :CallSid => call_sid } )
      Freshfone::Jobs::CallHistoryExport::CallHistoryExportWorker.new(@export_params).perform
      files = Dir.glob(@out_dir + '/*.csv')
      files.first.should_not be_blank
      csv_text = File.read(files.first)
      csv = CSV.parse(csv_text, :headers => true)
      csv.count.should be_eql(1)
      call = csv.first
      call["Helpdesk Number"].should be_eql(@freshfone_number.number)
      call["Call Status"].should be_eql("Answered")  # Change accordingly if TEST_CALL_STATUS is changed
      call["Agent Name"].should be_eql(@agent.name)
      call["Direction"].should be_eql(Freshfone::Call::CALL_TYPE_REVERSE_HASH[TEST_CALL_TYPE].to_s.capitalize)
    end

    it 'should export call records with their children' do
      create_call_family
      @account.freshfone_calls.each do |call| # Because call hist export skips ongoing calls
        call.update_attributes( { :call_status => Freshfone::Call::CALL_STATUS_STR_HASH['completed'] })
      end
      Freshfone::Jobs::CallHistoryExport::CallHistoryExportWorker.new(@export_params).perform
      files = Dir.glob(@out_dir + '/*.csv')
      files.first.should_not be_blank
      csv_text = File.read(files.first)
      csv = CSV.parse(csv_text, :headers => true)
      csv.count.should be_eql(2)
      csv[0]["Transfer Count"].to_i.should be_eql(1)
      csv[1]["Direction"].should be_eql("Transfer")
    end
  end

end