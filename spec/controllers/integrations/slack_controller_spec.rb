require 'spec_helper'
describe Integrations::SlackController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  before(:all) do
    @api_key = User.first.single_access_token
  end

  it "should show error if INVALID api key is passed" do
    post :create_ticket, {"api_key"=>"QDJ3HlJtJhHh0BM8jK3Z", "token"=>"CZVKmzSerBdevZaiFHN3OfQU", "team_id"=>"T02SCBF4W",
     "team_domain"=>"testprajwal", "channel_id"=>"D02ST26ES", "channel_name"=>"directmessage", "user_id"=>"U02SCBF50", 
     "user_name"=>"prajwalanother", "command"=>"/create_ticket", "text"=>"xoxp-2896389166-2896389170-2900566241-d86bb0",
      "controller"=>"integrations/slack", "action"=>"create_ticket"}  
     response.status == "200 OK"
  end

  it "should post INVALID channel if ticket is created in wrong channel " do
    post :create_ticket, {"token"=>"CZVKmzSerBdevZaiFHN3OfQU", "team_id"=>"T02SCBF4W", "team_domain"=>"testprajwal",
     "channel_id"=>"D02ST26ES", "channel_name"=>"general", "user_id"=>"U02SCBF50", "user_name"=>"prajwalanother", 
     "command"=>"/create_ticket", "text"=>"invalid token", 
     "api_key"=> @api_key, "controller"=>"integrations/slack", "action"=>"create_ticket"}
    response.status == "200 OK"
  end

  it "should redirect if INVALID token is passed" do
    post :create_ticket, {"token"=>"CZVKmzSerBdevZaiFHN3OfQU", "team_id"=>"T02SCBF4W", "team_domain"=>"testprajwal",
     "channel_id"=>"D02ST26ES", "channel_name"=>"general", "user_id"=>"U02SCBF50", "user_name"=>"prajwalanother", 
     "command"=>"/create_ticket", "text"=>"xoxp-2896389166-2896389170-2900566241-d86bb0", 
     "api_key"=> @api_key, "controller"=>"integrations/slack", "action"=>"create_ticket"}
    response.status == "200 OK"
  end

  it "should create a ticket in freshdesk " do
    post :create_ticket, {"token"=>"CZVKmzSerBdevZaiFHN3OfQU", "team_id"=>"T02SCBF4W", "team_domain"=>"testprajwal",
     "channel_id"=>"D02ST26ES", "channel_name"=>"directmessage", "user_id"=>"U02SCBF50", "user_name"=>"prajwalanother", 
     "command"=>"/create_ticket", "text"=>"xoxp-2896389166-2896389170-2900566241-d86bb0", 
     "api_key"=> @api_key, "controller"=>"integrations/slack", "action"=>"create_ticket"}
    response.status == "200 OK"
  end
end