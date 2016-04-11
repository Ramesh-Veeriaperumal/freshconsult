require 'spec_helper'

RSpec.describe Freshfone::CallMeta do 
  self.use_transactional_fixtures = false
  
  before(:each) do
    create_test_freshfone_account
  end

  it 'should create call meta data for a given call' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer])
    @freshfone_call_meta.save.should be true
  end

  it 'should update pinged agent response' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser}, {:id=>6, :ff_user_id=>5, :name=>"Tseve Wozniac", :device_type=>:browser}])
   
    @freshfone_call_meta.update_pinged_agents_with_response(@agent.id, "accepted").should be true
  end

  it 'should update agent call sid' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser}, {:id=>6, :ff_user_id=>5, :name=>"Tseve Wozniac", :device_type=>:browser}])
    @freshfone_call_meta.update_agent_call_sids(@agent.id, "CA2db76c748cb6f081853f80dace462a04").should be true   
  end

  it 'should have no missed agents' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser},{:id=>2, :ff_user_id=>2, :name=>"Steve", :device_type=>:browser}])
   
    @freshfone_call_meta.update_pinged_agents_with_response(1, "accepted")
    @freshfone_call_meta.update_pinged_agents_with_response(2, "completed")
    @freshfone_call_meta.all_agents_missed?.should be false
  end

   it 'should have missed agents' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser}])
   
    @freshfone_call_meta.update_pinged_agents_with_response(1, "busy")
    @freshfone_call_meta.all_agents_missed?.should be true
  end

   it 'should have agent response' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser}])
   
    @freshfone_call_meta.update_pinged_agents_with_response(1, "busy")
    @freshfone_call_meta.agent_response_present?(1).should be true
  end

  it 'should have no agent response' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser}])
   
    @freshfone_call_meta.agent_response_present?(1).should be false
  end


  it 'should update mobile agent call' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser}])
   
    @freshfone_call_meta.update_mobile_agent_call(@agent.id,"CA2db76c748cb6f081853f80dace462a04").should be true
  end

  it 'should update external transfer call' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser}])
   
    @freshfone_call_meta.update_external_transfer_call("+12407433321","CA2db76c748cb6f081853f80dace462a04").should be true
  end

  it 'should update external transfer call response' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser}])
   
    @freshfone_call_meta.update_external_transfer_call_response("+12407433321","accepted").should be true
  end

  it 'should contain user agent type hash values' do
    Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:browser].should be_eql(1)
    Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:android].should be_eql(2)
    Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:ios].should be_eql(3)
    Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:available_on_phone].should be_eql(4)
    Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:direct_dial].should be_eql(5)
    Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer].should be_eql(6)
  end

  it 'should contain pinged agent response hash values' do
    Freshfone::CallMeta::PINGED_AGENT_RESPONSE_HASH[:accepted].should be_eql(1)
    Freshfone::CallMeta::PINGED_AGENT_RESPONSE_HASH[:completed].should be_eql(1)
    Freshfone::CallMeta::PINGED_AGENT_RESPONSE_HASH[:'no-answer'].should be_eql(2)
    Freshfone::CallMeta::PINGED_AGENT_RESPONSE_HASH[:busy].should be_eql(3)
    Freshfone::CallMeta::PINGED_AGENT_RESPONSE_HASH[:canceled].should be_eql(4)
    Freshfone::CallMeta::PINGED_AGENT_RESPONSE_HASH[:failed].should be_eql(5)
  end

  it 'should contain pinged agent response hash values' do
    Freshfone::CallMeta::HUNT_TYPE_HASH[:agent].should be_eql(0)
    Freshfone::CallMeta::HUNT_TYPE_HASH[:group].should be_eql(1)
    Freshfone::CallMeta::HUNT_TYPE_HASH[:number].should be_eql(2)
    Freshfone::CallMeta::HUNT_TYPE_HASH[:simple_routing].should be_eql(3)
  end

  it 'should have a rating' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser},{:id=>2, :ff_user_id=>2, :name=>"Steve", :device_type=>:browser}])
   
    @freshfone_call_meta.update_feedback(:CallSid => "CA2db76c748cb6f081853f80dace462a04", :rating => "good")
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be_eql(:good)
  end

  it 'should have an issue for bad calls' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser},{:id=>2, :ff_user_id=>2, :name=>"Steve", :device_type=>:browser}])
   
    @freshfone_call_meta.update_feedback(:CallSid => "CA2db76c748cb6f081853f80dace462a04", :rating => "bad", :issue => 'dropped_call')
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be_eql(:bad)
    @freshfone_call_meta.meta_info[:quality_feedback][:issue].should be_eql(:dropped_call)
  end

   it 'should have comment for other issues' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser},{:id=>2, :ff_user_id=>2, :name=>"Steve", :device_type=>:browser}])
   
    @freshfone_call_meta.update_feedback(:CallSid => "CA2db76c748cb6f081853f80dace462a04", :rating => "bad", :issue => 'other_issues', :comment => "Bad Call Quality")
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be_eql(:bad)
    @freshfone_call_meta.meta_info[:quality_feedback][:issue].should be_eql(:other)
    @freshfone_call_meta.meta_info[:quality_feedback][:comment].should be_eql("Bad Call Quality")
  end

  it 'should not have a rating' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser},{:id=>2, :ff_user_id=>2, :name=>"Steve", :device_type=>:browser}])
   
    @freshfone_call_meta.update_feedback(:CallSid => "CA2db76c748cb6f081853f80dace462a04")
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be(nil)
    @freshfone_call_meta.meta_info[:quality_feedback][:issue].should be_eql(nil)
    @freshfone_call_meta.meta_info[:quality_feedback][:comment].should be_eql(nil)
  end

  it 'should not have issue for good calls' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser},{:id=>2, :ff_user_id=>2, :name=>"Steve", :device_type=>:browser}])
   
    @freshfone_call_meta.update_feedback(:CallSid => "CA2db76c748cb6f081853f80dace462a04", :rating => "good")
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be_eql(:good)
    @freshfone_call_meta.meta_info[:quality_feedback][:issue].should be_eql(nil)
    @freshfone_call_meta.meta_info[:quality_feedback][:comment].should be_eql(nil)
  end

  it 'should not have comment' do
    create_freshfone_number
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id, 
                                                      :call_type => 1, :agent => @agent)
    @freshfone_call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
                           :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
                           :pinged_agents => [{:id=>1, :ff_user_id=>1, :name=>"Support", :device_type=>:browser},{:id=>2, :ff_user_id=>2, :name=>"Steve", :device_type=>:browser}])
   
    @freshfone_call_meta.update_feedback(:CallSid => "CA2db76c748cb6f081853f80dace462a04", :rating => "bad", :issue => 'dropped_call')
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be_eql(:bad)
    @freshfone_call_meta.meta_info[:quality_feedback][:issue].should be_eql(:dropped_call)
    @freshfone_call_meta.meta_info[:quality_feedback][:comment].should be_eql(nil)
  end

end  