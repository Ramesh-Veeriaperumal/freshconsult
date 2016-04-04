require 'spec_helper'

describe Helpdesk::ConversationsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    # Raising the ticket with logged in agent as the requester so that meta notes wont be created
    @test_ticket = create_ticket({ :status => 2, :requester_id => @agent.id})
  end

  before(:each) do
    log_in(@agent)
  end
  
  it "should not add a private note to a ticket when the source does not include in the list" do
    post :note, {
                   :helpdesk_note => { :note_body_attributes =>{ :body => Faker::Lorem.sentence(3)},
                                        :private => "true",
                                        :source => "19"
                                      },
                   :ticket_status => "",
                   :format => "js",
                   :showing => "notes",
                   :ticket_id => @test_ticket.display_id
                  }
    response.content_type.should == Mime::JS
    private_note = @account.tickets.find(@test_ticket.id).notes.last
    private_note.should be_nil
  end
  
  it "should not add the reply to a ticket when source has a non numerical value" do
    note_body = Faker::Lorem.sentence(3)
    cc_email = Faker::Internet.email
    bcc_email = Faker::Internet.email
    Sidekiq::Testing.inline!
    source_text = Faker::Lorem.words(2).join(" ")
    post :reply, { :reply_email => { :id => "support@#{@account.full_domain}" },
                   :helpdesk_note => { :note_body_attributes =>{ :body_html => "<div>#{note_body}</div>",
                                                              :full_text_html =>"<div>#{note_body}</div>"},
                                        :cc_emails => cc_email,
                                        :bcc_emails => bcc_email,
                                        :private => "false",
                                        :source => source_text,
                                        :to_emails => Faker::Internet.email,
                                        :from_email => "support@#{@account.full_domain}"
                                      },
                   :ticket_status => "",
                   :format => "js",
                   :showing => "notes",
                   :ticket_id => @test_ticket.display_id
                  }
    Sidekiq::Testing.disable!
    response.content_type == Mime::JS
    reply_note = @account.tickets.find(@test_ticket.id).notes.last
    reply_note.should be_nil
  end
  
  it "should not forward a ticket that has invalid source" do
    fwd_body = Faker::Lorem.sentence(3)
    post :forward, { :reply_email => { :id => "support@#{@account.full_domain}" },
                   :helpdesk_note => { :note_body_attributes =>{ :body_html => "<div>#{fwd_body}</div>",
                                                              :full_text_html =>"<div>#{fwd_body}</div>"},
                                        :cc_emails => "",
                                        :bcc_emails => "",
                                        :private => "true",
                                        :source => "80",
                                        :to_emails => Faker::Internet.email,
                                        :from_email => "support@#{@account.full_domain}"
                                      },
                   :ticket_status => "",
                   :format => "js",
                   :showing => "notes",
                   :ticket_id => @test_ticket.display_id
                  }
    response.content_type == Mime::JS
    fwd_note = @account.tickets.find(@test_ticket.id).notes.last
    fwd_note.should be_nil
  end
  
  it "should not send a twitter reply to a ticket if source is invalid" do
    post :twitter,  { :helpdesk_note => {
                            :private => false, 
                            :source => 200, 
                            :note_body_attributes => {:body => Faker::Lorem.sentence(3) }
                         },
                        :tweet => true,
                        :tweet_type => "mention",
                        :ticket_id => @test_ticket.display_id ,
                        :ticket_status => "",
                        :format => "js"
                      }
    response.content_type == Mime::JS
    tweet_note = @account.tickets.find(@test_ticket.id).notes.last
    tweet_note.should be_nil
  end
  
  it "should not send a facebook reply to a ticket if source has a non numerical value" do
    post :facebook, {   :helpdesk_note => 
                              { :source => Faker::Lorem.sentence(3), 
                                :private => false, 
                                :note_body_attributes => {:body => Faker::Lorem.sentence(3) }
                              },
                            :fb_post => true,
                            :format => "js",
                            :ticket_status => "",
                            :showing => "notes",
                            :ticket_id => @test_ticket.display_id,
                        }
    response.content_type == Mime::JS
    fb_note = @account.tickets.find(@test_ticket.id).notes.last
    fb_note.should be_nil
  end
end