require 'spec_helper'

RSpec.configure do |c|
  c.include Import::CustomField
end

RSpec.describe ApiWebhooksController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
		#@account = create_test_account
	  @user = add_test_agent(@account)
	  f = { :field_type=>"custom_text", :label=>"abcd123", :label_in_portal=>"abcd1234", :description=>"", 
	  	:position=>10, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, 
	  	:editable_in_portal=>true, :required_in_portal=>false, :field_options=>nil, :type=>"text" }
		create_field(f, @account)
	end

	before(:each) do
    request.env["HTTP_ACCEPT"] = "application/json"
	  log_in(@user)
	end

	it "should create webhooks for user" do
		post :create, {"url"=>"http://requestb.in/14beecl1","name"=>"user_create","description"=>"testing",
									 "event_data"=>[{"name"=>"user_action","value"=>"create"}]}
		response.status.should eql(200)
	end

	it "should fail for create webhooks" do
		post :create, {"url"=>"http://requestb.in/14beecl1","name"=>"user_create","description"=>"testing",
									 "event_data"=>[{"name"=>"user_action","value"=>"delete"}]}
		response.status.should eql(422)
	end

	it "should delete webhooks" do
		id = VaRule.find(:first,:conditions=>["rule_type=13"]).id
		delete :destroy, {"controller"=>"api_webhooks", "action"=>"destroy", "id"=> id, "format"=>"json"}
		response.status.should eql 200
	end

	it "should create webhooks for ticket" do
		post :create, {"url"=>"http://testticketurl.com","name"=>"ticket_create","description"=>"testing",
									 "event_data"=>[{"name"=>"ticket_action","value"=>"create"}]}
		response.status.should eql 200
	end

	it "should create webhooks for note" do
		post :create, {"url"=> "http://testnoteurl.com","name"=>"note_create","description"=>"testing",
			"event_data"=>[{"name"=>"note_action","value"=>"create"}]}
		response.status.should eql 200
	end

	it "should create webhooks for note with username" do
		post :create, {"url"=> "http://testnotesurl.com","username" => "sathish@freshdesk.com", 
			"password" => "test","name"=>"note_create","description"=>"testing",
			"event_data"=>[{"name"=>"note_action","value"=>"create"}]}
		response.status.should eql 200
	end

	it "should create webhooks for note with api key" do
		post :create, {"url"=> "http://testnotesapi.com","api_key" => "BfPY67HoIscsgEbkSv","name"=>"note_create","description"=>"testing",
			"event_data"=>[{"name"=>"note_action","value"=>"create"}]}
		response.status.should eql 200
	end

	it "should create webhooks for ticket update" do
		post :create, {"url"=> "http://ticketupdate.com","name"=>"ticket_update","description"=>"testing",
			"event_data"=>[{"name"=>"ticket_action","value"=>"update"}]}
		response.status.should eql 200
	end

	it "should create webhooks for user update" do
		Resque.inline = true 
		post :create, {"url"=> "http://testnotesapi.com","api_key" => "BfPY67HoIscsgEbkSv","name"=>"note_create","description"=>"testing",
			"event_data"=>[{"name"=>"user_action","value"=>"update"}]}
		@ticket = create_ticket({:status => 2})
		@ticket.status=3
		@ticket.save!
		Resque.inline = false
		response.status.should eql 200
	end

	after(:all) do
		@account.observer_rules.destroy_all
	end

end