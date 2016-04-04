require 'spec_helper'

RSpec.describe Freshfone::Number do
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
  end

  after(:each) do
    Freshfone::Number.delete_all
    @account.freshfone_numbers = []
    @number = nil
  end

  it 'should return json of messages for the freshfone number' do
    number = @number.as_json
    number.should have(6).message_types
    number.map{|n| n[:type] }.sort.should be_eql([:hold_message,:non_availability_message, 
      :non_business_hours_message, :on_hold_message, :voicemail_message, :wait_message])
  end

  it 'should successfully renew number deducting credits' do
    expect {
      @number.renew
      @account.freshfone_credit.reload
    }.to change{(@account.freshfone_credit.available_credit.to_f-1)}
  end

  it 'should not update credits on unsuccessfull number renewal' do
    expect {
      Freshfone::Credit.any_instance.stubs(:renew_number).returns(false)
      @number.renew
      @account.freshfone_credit.reload
    }.to_not change{(@account.freshfone_credit.available_credit.to_f-1)}
  end

  it 'should return all numbers that are due today' do
    @number.update_attributes(:next_renewal_at => Time.zone.now)
    numbers_for_due = Freshfone::Number.find_due Time.zone.now
    numbers_for_due.should_not be_empty 
    numbers_for_due.first.number.should be_eql(@number.number)
  end

  it 'should return all numbers that are due today' do
    @number.update_attributes(:next_renewal_at => (Time.zone.now - 1.minute))
    numbers_for_due = Freshfone::Number.find_trial_account_due Time.zone.now
    numbers_for_due.should_not be_empty
    numbers_for_due.first.number.should be_eql(@number.number)
  end

  it 'should return false for insufficient renewal amount check with new recharge' do
    @number.insufficient_renewal_amount?.should be_falsey
  end

  it 'should have the queue wait time in minutes' do
    @number.queue_wait_time_in_minutes.should_not be_falsey
  end

  it 'should have voice type' do
    @number.voice_type.should_not be_falsey
  end
  
  it 'should have recording visibility' do
    @number.public_recording?.should be true
  end
  
  it 'should have number type' do
    @number.local?.should be true 
  end
  
  it 'should have voice' do
    @number.male_voice?.should be true
  end

  it 'should have a freshfone number' do
    @number.number_name.should_not be_falsey
  end

  it 'should return false for non business hours' do
    @number.non_business_hour_calls?.should be false
  end

  it 'should return empty string for unused attachments' do
    @number.unused_attachments.should == []
  end

  it 'should return ringing duration' do
    @number.ringing_duration.should == 30
  end

  it 'should have working hours' do
    Freshfone::Number.any_instance.stubs(:within_business_hours?).returns(false)
    @number.working_hours?.should be false
    Freshfone::Number.any_instance.unstub(:within_business_hours?)
  end

  it 'should have within business hours value' do
    @number.within_business_hours?.should_not == ""
  end

  it 'should be able to access an agent' do
    @number.can_access_by_agent?(@agent).should be true
  end

  it 'should have accesilble numbers' do
    Freshfone::Number.accessible_freshfone_numbers(@agent,["+12015524301"]).should_not be_falsey
  end

end