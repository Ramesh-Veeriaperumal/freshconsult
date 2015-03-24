require 'spec_helper'

include Redis::RedisKeys
include Redis::IntegrationsRedis
include Integrations::AppsUtil

RSpec.configure do |c|
  c.include Redis::RedisKeys
  c.include Redis::IntegrationsRedis
end

RSpec.describe Integrations::LogmeinController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    @redis_key = "INTEGRATIONS_LOGMEIN:#{@account.id}:#{@test_ticket.id}"
    @md5 = get_md5_secret
    @logmein_session_hash = {:agent_id=>@agent.id, :md5secret=>@md5,
														:pincode=>"384178", :pintime=>Time.now.to_s}
	@success_json = {:status => "Success"}.to_json
	@installed_application = @account.installed_applications.find_by_application_id(@installing_application)
    	if @installed_application.blank?
	    @installed_application = Integrations::InstalledApplication.new()
	    @installed_application.application = @installing_application
	    @installed_application.account = @account
	    app_param = {:title => "LogMeIn Rescue", :company_id => "sample@freshdesk.com", :password => "test"}
	    @installed_application.set_configs app_param
	    @installed_application.save(validate: false)
		end
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
		get :rescue_session , {"Tracking0"=>"INTEGRATIONS_LOGMEIN:#{@account.id}:#{@test_ticket.id}:" + @md5,
													 "ChatLog" => "SOME RANDOM TEXT", "Note" => "SOME RANDOM TEXT",
													 "SessionID" => "1234567890", "TechName" => "RANDOM NAME",
													 "TechEmail" => "RANDOM EMAIL", "Platform" => @request.user_agent,
													 "WorkTime" => Time.now.to_s, :format=>"json"}
		response.body.should == @success_json
		@test_ticket.notes.should_not be_empty
		@test_ticket.notes.last.note_body.body.start_with?('Your LogMeIn Rescue Session details').should be_truthy
		get_integ_redis_key(@redis_key).should be_nil
	end

	it "should parse the liquid data" do
	note = create_note({:source => @test_ticket.source,
                               :ticket_id => @test_ticket.id,
                               :body => "test body",
                               :user_id => @agent.id})
	ext_id=20606
	ext_note = Helpdesk::ExternalNote.new
	ext_note.account_id = @agent.account_id
	ext_note.note_id = note.id
	ext_note.installed_application_id = @installed_application.id
	ext_note.external_id = ext_id
	ext_note.save
	liquid_template = {:select=>"helpdesk_notes.*", :joins=>"INNER JOIN helpdesk_external_notes ON helpdesk_external_notes.note_id=helpdesk_notes.id and helpdesk_external_notes.account_id = helpdesk_notes.account_id", :conditions=>["helpdesk_external_notes.external_id=?", "{{comment.id}}"]}
	data = {"comment" => {"id" => ext_id }}
	resp = replace_liquid_values(liquid_template,data)
	resp[2][1].to_i.should eql ext_id
	end
end
