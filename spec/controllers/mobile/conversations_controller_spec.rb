require 'spec_helper'

describe Helpdesk::ConversationsController do
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Convo"}))
    @group = @account.groups.first
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Freshdesk_Native_Android"
    @request.accept = "application/json"
    @request.env['HTTP_AUTHORIZATION'] =  ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token,"X")
    @request.env['format'] = 'json'
  end

  it "should send a reply to the ticket" do
    now = (Time.now.to_f*1000).to_i
    cc_email = Faker::Internet.email
    bcc_email = Faker::Internet.email

    post :reply, {:showing =>"notes", 
                  :format =>"json", 
                  :ticket_status =>"", 
                  :xhr=>"true", 
                  :helpdesk_note => {:source=>"0", 
                                    :private=>"false", 
                                    :to_emails=>"rachel@freshdesk.com", 
                                    :bcc_emails=>"", 
                                    :cc_emails=>"", 
                                    :from_email=>"support@#{@account.full_domain}",
                                    :note_body_attributes=>{
                                        :body_html=>"<div>#{now}</div>",
                                        :full_text_html=>"<div>#{now}</div>"
                                        } 
                                    }, 
                  :include_bcc =>"on", 
                  :include_cc =>"on", 
                  :reply_email=>{"id"=>"support@#{@account.full_domain}"}, 
                  :ticket_id=>@test_ticket.display_id
                  }
    json_response["server_response"].should be_true
    replied_ticket = @account.tickets.find(@test_ticket.id)
    ticket_reply = replied_ticket.notes.last
    ticket_reply.full_text_html.should be_eql("<div>#{now}</div>")
  end

  it "should forward a ticket" do
    now = (Time.now.to_f*1000).to_i
    post :forward, { "showing"=>"notes", 
                     "format"=>"json", 
                     "ticket_status"=>"", 
                     "xhr"=>"true", 
                     "helpdesk_note"=> { 
                          "source"=>"8", 
                          "private"=>"true", 
                          "to_emails"=>"mgbharath@ymail.co.in,", 
                          "bcc_emails"=>"", 
                          "cc_emails"=>"", 
                          "from_email"=>"support@localhost.freshdesk-dev.com", 
                          "note_body_attributes"=>  { "body_html"=>"<div>#{now}</div>",
                                                     "full_text_html"=>"<div>#{now}</div>"
                                                    }
                                       }, 
                     "include_bcc"=>"on", 
                     "include_cc"=>"on", 
                     "reply_email"=>{"id"=>""}, 
                     "controller"=>"helpdesk/conversations", 
                     "action"=>"forward", 
                     "ticket_id"=>@test_ticket.display_id }
    json_response["server_response"].should be_true
    @account.tickets.find(@test_ticket.id).notes.last.full_text_html.should be_eql("<div>#{now}</div>")
  end

  it "should add a private note to a ticket" do
    now = (Time.now.to_f*1000).to_i
    post :note, { "showing"=>"notes", 
                  "format"=>"json", 
                  "ticket_status"=>"", 
                  "xhr"=>"true", 
                  "helpdesk_note" => {"source"=>"2", 
                                      "private"=>"1", 
                                      "to_emails"=>"sample@samplefd.com, ", 
                                      "note_body_attributes"=> { "body_html"=>"<div>#{now}</div>" }
                                      }, 
                  "controller"=>"helpdesk/conversations", 
                  "action"=>"note", 
                  "ticket_id"=>@test_ticket.display_id 
                }
    json_response["server_response"].should be_true
    private_note = @account.tickets.find(@test_ticket.id).notes.last
    private_note.body_html.should be_eql("<div>#{now}</div>")
    private_note.private.should be_true
  end

  it "should send a twitter reply to a ticket" do
    post :twitter,  { :helpdesk_note => {
                            :private => false, 
                            :source => 5, 
                            :note_body_attributes => {:body => Faker::Lorem.sentence(3) }
                         },
                        :tweet => true,
                        :tweet_type => "mention",
                        :ticket_id => @test_ticket.display_id ,
                        :ticket_status => "",
                        :format => "json"
                      }
    json_response.should include("server_response")
    json_response["server_response"].should be_true
  end
end