require 'spec_helper'
load 'spec/support/freshfone_spec_helper.rb'
include FreshfoneSpecHelper

describe Freshfone::User do 
  self.use_transactional_fixtures = false
  
  before(:each) do
    create_test_freshfone_account
  end

  it 'should render twiml that connects to agent mobile' do
    create_online_freshfone_user
    @freshfone_user.update_attributes(:available_on_phone => true)
    number = GlobalPhone.parse(Faker::Base.numerify('(###)###-####')).international_string
    @freshfone_user.user.update_attributes(:phone => number)
    xml_builder = Twilio::TwiML::Response.new do |r|
      r.Dial do |d|
        @freshfone_user.send(:call_agent_on_phone, d, "/forward/phone")
      end
    end
    twiml = twimlify xml_builder.text
    twiml[:Response][:Dial][:Number].should be_eql(number)
    @freshfone_user.update_attributes(:available_on_phone => false)
  end

  it 'should return true for valid phone number check' do
    create_online_freshfone_user
    number = GlobalPhone.parse(Faker::Base.numerify('(###)###-####')).international_string
    @freshfone_user.user.update_attributes(:phone => number)
    @freshfone_user.reload
    @freshfone_user.send(:vaild_phone_number?, @number).should be_true
  end
end