require 'spec_helper'

describe Helpdesk::ConversationsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Convo"}))
    @group = @account.groups.first
  end

  before(:each) do
    @request.host = @account.full_domain
    log_in(@user)
  end

  it "should send a reply to the ticket, with CC and BCC emails, assign responder as agent" do
    now = (Time.now.to_f*1000).to_i
    cc_email = Faker::Internet.email
    bcc_email = Faker::Internet.email
    Resque.inline = true
    post :reply, { :reply_email => { :id => "support@#{@account.full_domain}" }, 
                   :helpdesk_note => { :note_body_attributes =>{ :body_html => "<div>#{now}</div>", 
                                                              :full_text_html =>"<div>#{now}</div>"}, 
                                        :cc_emails => cc_email, 
                                        :bcc_emails => bcc_email, 
                                        :private => "false", 
                                        :source => "0", 
                                        :to_emails => "rachel@freshdesk.com", 
                                        :from_email => "support@#{@account.full_domain}"
                                      }, 
                   :ticket_status => "", 
                   :format => "js", 
                   :showing => "notes", 
                   :since_id => "197",
                   :ticket_id => @test_ticket.display_id
                  }
    Resque.inline = false
    response.should render_template "helpdesk/notes/create.rjs"
    replied_ticket = @account.tickets.find(@test_ticket.id)
    replied_ticket.responder_id.should be_eql(@user.id)
    ticket_reply = replied_ticket.notes.last
    ticket_reply.full_text_html.should be_eql("<div>#{now}</div>")
    ticket_reply.cc_emails.should be_eql([cc_email])
    ticket_reply.bcc_emails.should be_eql([bcc_email])
  end

  it "should forward a ticket" do
    now = (Time.now.to_f*1000).to_i
    post :forward, { :reply_email => { :id => "support@#{@account.full_domain}" }, 
                   :helpdesk_note => { :note_body_attributes =>{ :body_html => "<div>#{now}</div>", 
                                                              :full_text_html =>"<div>#{now}</div>"}, 
                                        :cc_emails => "", 
                                        :bcc_emails => "", 
                                        :private => "true", 
                                        :source => "8", 
                                        :to_emails => "rachel@freshdesk.com", 
                                        :from_email => "support@#{@account.full_domain}"
                                      }, 
                   :ticket_status => "", 
                   :format => "js", 
                   :showing => "notes", 
                   :since_id => "197",
                   :ticket_id => @test_ticket.display_id
                  }
    response.should render_template "helpdesk/notes/create.rjs"
    @account.tickets.find(@test_ticket.id).notes.last.full_text_html.should be_eql("<div>#{now}</div>")
  end

  it "should add a private note to a ticket" do
    now = (Time.now.to_f*1000).to_i
    post :note, { :reply_email => { :id => "support@#{@account.full_domain}" }, 
                   :helpdesk_note => { :note_body_attributes =>{ :body_html => "<div>#{now}</div>"}, 
                                        :private => "true", 
                                        :source => "2"
                                      }, 
                   :ticket_status => "", 
                   :format => "js", 
                   :showing => "notes", 
                   :since_id => "197",
                   :ticket_id => @test_ticket.display_id
                  }
    response.should render_template "helpdesk/notes/create.rjs"
    private_note = @account.tickets.find(@test_ticket.id).notes.last
    private_note.full_text_html.should be_eql("<div>#{now}</div>")
    private_note.private.should be_true
  end
end