require 'spec_helper'
          
describe Freshfone::CallerIdController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @account.freshfone_caller_id.delete_all
    create_test_freshfone_account
    @request.host = @account.full_domain
    log_in(@agent)
  end

  it 'should return true on caller id verification if number verified' do
    create_freshfone_outgoing_caller
    params = { :number => "+1234567890"}
    post :verify, params
    json.should have_key(:caller)
    json[:caller].should_not == nil
    Freshfone::CallerId.find(@outgoing_caller.id).should_not == nil
  end

  it 'should return false on caller id verification if number not verified' do
    params = { :number => "+9234567890"}
    post :verify, params
    json.should have_key(:caller)
    json[:caller].should == nil
  end
  
  it 'should not create an outgoing caller if number verification fails' do
    params = { :number => "+1234567890"}
    post :validation, params
    json.should have_key(:error_message)
    json[:error_message].should_not == nil
  end

  it 'should create an outgoing caller if number verification succeeds' do
    outgoing_caller = {"validation_code" => "123456" , "phone_number" => "+1234567890"}
    outgoing_caller = OpenStruct.new outgoing_caller
    Twilio::REST::OutgoingCallerIds.any_instance.stubs(:create).returns(outgoing_caller)
    params = { :number => "+1234567890"}
    post :validation, params
    json.should have_key(:code)
    json[:code].should_not == nil
    Twilio::REST::OutgoingCallerIds.any_instance.unstub(:create)
  end
  
  it 'should delete the caller id if already verified' do
    create_freshfone_outgoing_caller
    outgoing_caller = {"delete" => true , "phone_number" => "+1234567890"}
    outgoing_caller = OpenStruct.new outgoing_caller
    Twilio::REST::OutgoingCallerIds.any_instance.stubs(:get).returns(outgoing_caller)
    params = { :caller_id => @outgoing_caller.id, :number => "+91234567890", :number_sid => "PN2ba4c66ed6a57e8311eb0f14d5aa2d88"}
    post :delete, params
    json.should have_key(:deleted)
    json[:deleted].should == true
    Twilio::REST::OutgoingCallerIds.any_instance.unstub(:get)
  end

  it 'should not delete the caller id if not verified' do
    create_freshfone_outgoing_caller
    outgoing_caller = {"delete" => true , "phone_number" => "+1234567890"}
    outgoing_caller = OpenStruct.new outgoing_caller
    Twilio::REST::OutgoingCallerIds.any_instance.stubs(:get).returns(outgoing_caller)
    params = { :number => "+91234567890", :number_sid => "PN2ba4c66ed6a57e8311eb0f14d5aa2d88"}
    post :delete, params
    json.should have_key(:deleted)
    json[:deleted].should == false
    Twilio::REST::OutgoingCallerIds.any_instance.unstub(:get)
  end

end