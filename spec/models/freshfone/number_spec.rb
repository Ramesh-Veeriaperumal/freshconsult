require 'spec_helper'
load 'spec/support/freshfone_spec_helper.rb'
include FreshfoneSpecHelper

describe Freshfone::Number do 
  self.use_transactional_fixtures = false
  
  before(:each) do
    create_test_freshfone_account
  end

  after(:each) do
    Freshfone::Number.delete_all
  end

  it 'should return json of messages for the freshfone number' do
    number = JSON.parse @number.to_json
    number.should have(4).message_types
    number.map{|n| n["type"]}.sort.should be_eql(["non_availability_message", 
      "non_business_hours_message", "on_hold_message", "voicemail_message"])
  end

  it 'should successfully renew number deducting credits' do
    expect {
      @number.renew
      @account.freshfone_credit.reload
    }.to change{@account.freshfone_credit.available_credit.to_f}.by(-1)
  end

  it 'should not update credits on unsuccessfull number renewal' do
    expect {
      Freshfone::Credit.any_instance.stubs(:renew_number).returns(false)
      @number.renew
      @account.freshfone_credit.reload
    }.to_not change{@account.freshfone_credit.available_credit.to_f}.by(-1)
  end

end