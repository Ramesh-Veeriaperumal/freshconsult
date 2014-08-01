require 'spec_helper'

describe Widgets::FeedbackWidgetsController do
  	self.use_transactional_fixtures = false

    before(:each) do
      @request.user_agent = "Freshdesk_Native_Android"
      @request.accept = "application/json"
      @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64("#{@agent.single_access_token}:X").delete("\r\n")}"
      @request.format = "json"
    end

  	it "should create a mobile feedback support ticket" do
    now = (Time.now.to_f*1000).to_i
    post :create, :helpdesk_ticket => {:email => "rachel@freshdesk.com",
                                       :subject => "New Ticket #{now}",
                                       :ticket_body_attributes => {
                                            :description_html => Faker::Lorem.sentence(3)
                                          }
                                        } 
                                       
    @account.tickets.find_by_subject("New Ticket #{now}").should be_an_instance_of(Helpdesk::Ticket)
    json_response["success"].should be_eql(true)
  end

end

