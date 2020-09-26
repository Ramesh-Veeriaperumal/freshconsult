require 'spec_helper'

RSpec.configure do |c|
  c.include FreshfoneSpecHelper
end

RSpec.describe Freshfone::SupervisorControl do 
  self.use_transactional_fixtures = false

  
  before(:all) do
    @account.freshfone_calls.destroy_all
  end
  
  before(:each) do
    create_test_freshfone_account
    @account.freshfone_calls.destroy_all
    @account.freshfone_callers.delete_all
    create_freshfone_number
    @freshfone_call = create_freshfone_call
  end

  after(:each) do
    @supervisor_control.destroy
  end

 it 'should have an active supervisor' do
    @supervisor_control= create_supervisor_call @freshfone_call
    @freshfone_call.supervisor_controls.active.first.should_not be_blank
  end
 
  it 'should not have an active supervisor' do
    @supervisor_control= create_supervisor_call @freshfone_call,
                                  Freshfone::SupervisorControl::CALL_STATUS_HASH[:failed]
    @freshfone_call.supervisor_controls.active.first.should be_blank
  end

  it 'should update the supervisor control details' do
    @supervisor_control= create_supervisor_call @freshfone_call
    params = {:CallDuration => 15, :status => 1}
    @supervisor_control.update_details(params).should be true
    expect(@supervisor_control.duration).to eq(15)
    expect(@supervisor_control.supervisor_control_status).to eq(Freshfone::SupervisorControl::CALL_STATUS_HASH[:success])
    
  end
end