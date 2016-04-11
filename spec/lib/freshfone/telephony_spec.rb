require 'spec_helper'
RSpec.configure do |c|
  c.include ConferenceTransferSpecHelper
end


RSpec.configure do |c|
  c.include Freshfone::Endpoints
  c.include Freshfone::FreshfoneUtil
  c.include Freshfone::NumberMethods
end

RSpec.describe Freshfone::Telephony do
  setup :activate_authlogic
  self.use_transactional_fixtures = false


  before(:each) do
    create_test_freshfone_account
    @account.freshfone_calls.destroy_all
    @account.freshfone_callers.delete_all
    create_freshfone_conf_call('CONFCALL')
    @telephony = Freshfone::Telephony.new({},@account,@number)
  end

  it "should return_non_availability message and go to voicemail" do
    stub_twilio_queues
    xml = @telephony.return_non_availability
    expect(xml).to match(/Response/)
    expect(xml).to match(/Record/)
  end

  it "should initiate queue successfully" do
    stub_twilio_queues
    @number.update_attributes({:max_queue_length =>2})
    @number.reload
    xml = @telephony.initiate_queue(:initiated)
    expect(xml).to match(/Response/)
    expect(xml).to match(/Enqueue/)
  end

  it "should initiate_voicemail successfully" do
    stub_twilio_queues
    xml = @telephony.initiate_voicemail
    expect(xml).to match(/Response/)
    expect(xml).to match(/Record/)
  end

   it "should return non_business_hour_calls message successfully" do
    stub_twilio_queues
    xml = @telephony.return_non_business_hour_call
    expect(xml).to match(/Response/)
    expect(xml).to match(/Say/)
  end

  it "should return incoming missed twiml properly" do
    stub_twilio_queues
    xml = @telephony.incoming_missed
    expect(xml).to match(/Response/)
    expect(xml).to match(/Call disconnected by the caller/)
  end

end