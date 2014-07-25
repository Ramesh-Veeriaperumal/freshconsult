require 'spec_helper'

describe ApiWebhooksController do
	integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
		@account = create_test_account
	  @user = add_test_agent(@account)
	end

	before(:each) do
	  log_in(@user)
	end

	it "should create webhooks for user" do
		post :create, {"url"=>"http://requestb.in/14beecl1","name"=>"user_create","description"=>"testing",
									 "event_data"=>[{"name"=>"user_action","value"=>"create"}]}
		response.status.should eql "200 OK"
	end

	it "should fail for create webhooks" do
		post :create, {"url"=>"http://requestb.in/14beecl1","name"=>"user_create","description"=>"testing",
									 "event_data"=>[{"name"=>"user_action","value"=>"delete"}]}
		response.status.should eql "422 Unprocessable Entity"
	end

	it "should delete webhooks" do
		id = VARule.find(:first,:conditions=>["rule_type=13"]).id
		delete :destroy, {"controller"=>"api_webhooks", "action"=>"destroy", "id"=> id, "format"=>"json"}
		response.status.should eql "200 OK"
	end

	it "should create webhooks for ticket" do
		post :create, {"url"=>"http://testticketurl","name"=>"ticket_create","description"=>"testing",
									 "event_data"=>[{"name"=>"ticket_action","value"=>"create"}]}
		response.status.should eql "200 OK"
	end

	it "should create webhooks for note" do
		post :create, {"url"=> "http://testnoteurl","name"=>"note_create","descriptionion"=>"testing",
			"event_data"=>[{"name"=>"note_action","value"=>"create"}]}
		response.status.should eql "200 OK"
	end

	it "should create webhooks for note with username" do
		post :create, {"url"=> "http://testnotesurl","username" => "sathish@freshdesk.com", 
			"password" => "test","name"=>"note_create","descriptionion"=>"testing",
			"event_data"=>[{"name"=>"note_action","value"=>"create"}]}
		response.status.should eql "200 OK"
	end

	it "should create webhooks for note with api key" do
		post :create, {"url"=> "http://testnotesapi","api_key" => "BfPY67HoIscsgEbkSv","name"=>"note_create","descriptionion"=>"testing",
			"event_data"=>[{"name"=>"note_action","value"=>"create"}]}
		response.status.should eql "200 OK"
	end

end