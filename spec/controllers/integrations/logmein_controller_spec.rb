require 'spec_helper'
include Redis::RedisKeys
include Redis::IntegrationsRedis

describe Integrations::LogmeinController do
	# integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    @redis_key = "INTEGRATIONS_LOGMEIN:#{@account.id}:#{@test_ticket.id}"
    @logmein_session_hash = {:agent_id=>@agent.id, :md5secret=>"8bf92a753625442c3f95d0e0fbb22e04",
														:pincode=>"384178", :pintime=>Time.now.to_s}
		@success_json = {:status => "Success"}.to_json
	end

	before(:each) do
		log_in(@agent)
	end

	it "should update pincode on redis" do
		set_integ_redis_key(@redis_key, @logmein_session_hash.to_json)
		new_logmein_session_hash = @logmein_session_hash.merge({:pincode => "123456"})
		put :update_pincode, {:ticket_id=>@test_ticket.id, :account_id=>@account.id,
													:logmein_session=>new_logmein_session_hash.to_json, :format=>"json"}
		response.body.should == @success_json
		get_integ_redis_key(@redis_key).should == new_logmein_session_hash.to_json
	end

	it "should create a note for a ticket and remove a redis key" do
		set_integ_redis_key(@redis_key, @logmein_session_hash.to_json)
		get :rescue_session , {"Tracking0"=>"INTEGRATIONS_LOGMEIN:#{@account.id}:#{@test_ticket.id}:8bf92a753625442c3f95d0e0fbb22e04",
													 "ChatLog" => "SOME RANDOM TEXT", "Note" => "SOME RANDOM TEXT",
													 "SessionID" => "1234567890", "TechName" => "RANDOM NAME",
													 "TechEmail" => "RANDOM EMAIL", "Platform" => @request.user_agent,
													 "WorkTime" => Time.now.to_s, :format=>"json"}
		response.body.should == @success_json
		@test_ticket.notes.should_not be_empty
		@test_ticket.notes.first.note_body.body.start_with?('Your LogMeIn Rescue Session details').should be_truthy
		get_integ_redis_key(@redis_key).should be_nil
	end
end
