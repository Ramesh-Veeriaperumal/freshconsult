require 'spec_helper'

describe Freshfone::DeviceController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
  end

  it 'should_save_recording_url_and_render_record_twiml' do
    set_twilio_signature("freshfone/device/record?agent=#{@agent.id}&number_id=1", 
                          record_params.except("agent", "number_id"))
    post :record, record_params
    recording_url = controller.get_key("FRESHFONE:RECORDING:#{@account.id}:#{@agent.id}")
    recording_url.should be_eql("http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/REa618f1f9d5cbf4117cb4121bc2aa5a0b")
    xml.should be_eql({:Response=>{:Say=>"Preparing your recorded message. Make sure you save the settings upon completion."}})
  end

  it 'shoudl retrieve the recording url from redis' do
    log_in(@agent)
    get :recorded_greeting
    json.should be_eql({ :url => 
      "http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/REa618f1f9d5cbf4117cb4121bc2aa5a0b" })
  end
end