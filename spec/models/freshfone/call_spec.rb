require 'spec_helper'

RSpec.describe Freshfone::Call do 
  self.use_transactional_fixtures = false
  
  before(:each) do
    create_test_freshfone_account
  end

  it 'should create a new freshfone call' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call.save.should be true
  end

  it 'should update freshfone call' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    params={:ConferenceSid=>"CA2db76c748cb6f081853f80dace462a04" , :DialCallSid=>"CA2db76c748cb6f081853f80dace462a04",
            :RecordingUrl=>"http://api.twilio.com/2010-04-01/Accounts/AC/Recordings/REf",:DialCallDuration=>15,:RecordingDuration=>15,
           :direc_dial_number=>"+16617480240", :total_duration=>20}
    @freshfone_call.save.should be true
    @freshfone_call.update_call(params).should be true
  end  

  it 'should update freshfone agent' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    params={:ConferenceSid=>"CA2db76c748cb6f081853f80dace462a04" , :DialCallSid=>"CA2db76c748cb6f081853f80dace462a04",
            :RecordingUrl=>"http://api.twilio.com/2010-04-01/Accounts/AC/Recordings/REf",:DialCallDuration=>15,:RecordingDuration=>15,
           :direc_dial_number=>"+16617480240", :total_duration=>20}
    @freshfone_call.save.should be true
    @freshfone_call.update_agent(@agent).should be true
  end  

  it 'should delete call recording' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent,:recording_url=>"http://api.twilio.com/2010-04-01/Accounts/AC/Recordings/REf")
    @freshfone_call.save.should be true
    @freshfone_call.delete_recording(@agent.id).should be true
  end  

  it 'should have customer sid' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent,
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be true
    @freshfone_call.customer_sid.should_not be_nil
  end  

  it 'should have hold leg sid' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent,
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be true
    @freshfone_call.hold_leg_sid.should_not be_nil
  end 

  it 'should have agent sid' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 2, :agent => @agent,
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be true
    @freshfone_call.agent_sid.should_not be_nil
  end 

  it 'should be able to log agent' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent,
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be true
    @freshfone_call.can_log_agent?.should be true
  end 

  it 'should have notable type' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent,
                                                      :notable_type => "Helpdesk::Ticket",
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be true
    @freshfone_call.ticket_notable?.should be true
  end 

  it 'should be a conference call' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent,
                                                      :conference_sid => "CA2db76c748cb6f081853f80dace462a04",
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04"})
    @freshfone_call.save.should be true
    @freshfone_call.conference?.should be true
  end  

  it 'should contain a call with given sid' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create( :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.call_sid.should == "CA2db76c748cb6f081853f80dace462a04"
  end  

  it 'should have call direction' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create( :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.direction_in_words.should == "From"
  end  

  it 'should have notable object' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create( :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,
                                      :notable_type =>"Helpdesk::Ticket",:notable_id =>1,
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.notable_present?.should be true
  end  

  it 'should disconnect agent' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 2, :agent => @agent,
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be true
    @freshfone_call.disconnect_agent.should be true
  end  

  it 'should disconnect customer' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent,
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be true
    @freshfone_call.disconnect_customer.should be true
  end 

  it 'should clean up one legged call' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent,
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be true
    @freshfone_call.cleanup_one_legged_call.should be true
  end  

  it 'should have dial call leg' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent,
                                                      :dial_call_sid => "CA2db76c748cb6f081853f80dace462a04",
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be true
    @freshfone_call.dial_call_leg?("CA2db76c748cb6f081853f80dace462a04").should be true
  end   

  it 'should add hold duration of call' do
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent,
                                                      :call_status =>2,
                                                      :hold_duration => 10,
                                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be true
    @freshfone_call.add_to_hold_duration(10).should be true
  end   

  it 'should not create a freshfone call if it has no account specified' do
    @freshfone_call = @account.freshfone_calls.create( :freshfone_number_id => @number.id, 
                                      :call_status => 0,:params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be false
  end  
 
  it 'should not create a freshfone call if call type is not specified' do
    @freshfone_call = @account.freshfone_calls.create( :freshfone_number_id => @number.id, 
                                      :call_status => 0, :agent => @agent,
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be false
  end  

   it 'should not create a freshfone call if number is not specified' do
    @freshfone_call = @account.freshfone_calls.create( :call_type => 1, 
                                      :call_status => 0, :agent => @agent,
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    @freshfone_call.save.should be false
  end  

end