require 'spec_helper'

describe Freshfone::VoicemailController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    create_freshfone_call
    @request.host = @account.full_domain
  end

  it 'should update call on quitting voicemail' do
    set_twilio_signature('freshfone/voicemail/quit_voicemail', voicemail_params)
    post :quit_voicemail, voicemail_params
    
    current_call = controller.current_call
    xml.should have_key(:Response)
    current_call.recording_url.should_not be_blank
    current_call.reload
    current_call.should be_voicemail
  end

end