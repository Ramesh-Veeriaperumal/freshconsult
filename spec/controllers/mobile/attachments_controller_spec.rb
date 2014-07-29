require 'spec_helper'

describe Helpdesk::AttachmentsController do
    self.use_transactional_fixtures = false

  before(:each) do
  	api_login
	end

	it "should return attachment array" do
		ticket = create_ticket({ :status => 2, 
                             :requester_id => @agent.id,
                             :attachments => { :resource => fixture_file_upload('files/image.gif', 'image/gif'),
                                               :description => Faker::Lorem.characters(10) 
                                              } })
		get :show, { :id => ticket.attachments.first.id, :format => "json" }
		json_response.should include("url")
	end
end