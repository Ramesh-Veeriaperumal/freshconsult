require 'spec_helper'

RSpec.configure do |c|
  c.include GnipHelper
  c.include DynamoHelper
end

RSpec.describe Helpdesk::ConversationsController do
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Convo"}))
    @group = @account.groups.first
  end

  before(:each) do
    api_login
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
    json_response["server_response"].should be true
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
    json_response["server_response"].should be true
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
    json_response["server_response"].should be true
    private_note = @account.tickets.find(@test_ticket.id).notes.last
    private_note.body_html.should be_eql("<div>#{now}</div>")
    private_note.private.should be true
  end

  it "should send a twitter reply to a ticket" do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @handle.update_attributes(:capture_dm_as_ticket => true)
    @default_stream = @handle.default_stream
    @ticket_rule = create_test_ticket_rule(@default_stream)
    update_db(@default_stream) unless GNIP_ENABLED
    @rule = {:rule_value => @default_stream.data[:rule_value] , :rule_tag => @default_stream.data[:rule_tag]}
    Resque.inline = false
    @account = @handle.account

    unless GNIP_ENABLED
      Social::DynamoHelper.stubs(:insert).returns({})
      Social::DynamoHelper.stubs(:update).returns({})
    end

    includes = @default_stream.includes
    @ticket_rule.filter_data[:includes] = includes
    @ticket_rule.save
    feed = sample_gnip_feed(@rule)
    tweet = send_tweet_and_wait(feed)
    
    tweet.should_not be_nil
    tweet.is_ticket?.should be true
    tweet.stream_id.should_not be_nil
    tweet_body = feed["body"]
    ticket = tweet.get_ticket
    body = ticket.ticket_body.description
    tweet_body.should eql(body)

    
    # stub the reply call
    twitter_object = sample_twitter_object
    Twitter::REST::Client.any_instance.stubs(:update).returns(twitter_object)
    unless GNIP_ENABLED
      Social::DynamoHelper.stubs(:update).returns(dynamo_update_attributes(twitter_object[:id]))
      Social::DynamoHelper.stubs(:get_item).returns(sample_dynamo_get_item_params)
    end
    post :twitter,  { :helpdesk_note => {
                        :private => false, 
                        :source => 5, 
                        :note_body_attributes => {:body => twitter_object[:text].dup }
                     },
                    :tweet => true,
                    :tweet_type => "mention",
                    :twitter_handle => @handle.id,
                    :ticket_id => ticket.display_id ,
                    :ticket_status => "",
                    :format => "json"
                  }
    json_response.should include("server_response")
    json_response["server_response"].should be true
  end
end