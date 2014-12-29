require 'spec_helper'

describe Helpdesk::ConversationsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  include APIAuthHelper

  context "For Web requests" do
    before(:all) do
      @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Convo"}))
      @group = @account.groups.first
    end

    before(:each) do
      log_in(@agent)
      stub_s3_writes
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
                                          :to_emails => Faker::Internet.email,
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
      replied_ticket.responder_id.should be_eql(@agent.id)
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
                                          :to_emails => Faker::Internet.email,
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

    it "should forward a ticket with attachment" do
      now = (Time.now.to_f*1000).to_i
      new_ticket = create_ticket({:status => 2,
                                  :attachments => {:resource => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
                                                    :description => Faker::Lorem.characters(10)
                                                  }
                                    }, @group)
      attachment = @account.attachments.find_by_attachable_id(new_ticket.id)
      attachment.should_not be_nil
      attachment.attachable_type.should eql "Helpdesk::Ticket"
      post :forward, {:reply_email => { :id => "support@#{@account.full_domain}" },
                      :helpdesk_note => { :note_body_attributes =>{ :body_html => "<div>#{now}</div>",
                                                                    :full_text_html =>"<div>#{now}</div>"},
                                          :attachments => [{:resource => "#{attachment.id}",:description => "<div>note_attachment</div>"}], 
                                          :cc_emails => "",
                                          :bcc_emails => "",
                                          :private => "true",
                                          :source => "8",
                                          :to_emails => Faker::Internet.email,
                                          :from_email => "support@#{@account.full_domain}"
                                        },
                     :ticket_status => "",
                     :format => "js",
                     :showing => "notes",
                     :since_id => "197",
                     :ticket_id => new_ticket.display_id
                    }
      new_ticket.reload
      new_note = new_ticket.notes.first
      new_note.should_not be_nil
      item = @account.attachments.find_by_attachable_id(new_note.id)
      item.should_not be_nil
      item.attachable_type.should eql "Helpdesk::Note"
      response.should render_template "helpdesk/notes/create.rjs"
      @account.tickets.find(new_ticket.id).notes.last.full_text_html.should be_eql("<div>#{now}</div>")
    end

    it "should not forward a ticket with attachment_resource nil" do
      now = (Time.now.to_f*1000).to_i
      test_ticket = create_ticket({ :status => 2 }, @groups)
      begin
        post :forward, { :reply_email => { :id => "support@#{@account.full_domain}" },
                         :helpdesk_note => { :note_body_attributes =>{:body_html => "<div>#{now}</div>",
                                                                      :full_text_html =>"<div>#{now}</div>"},
                                            :cc_emails => "",
                                            :attachments => [{:resource => ""}],
                                            :bcc_emails => "",
                                            :private => "true",
                                            :source => "8",
                                            :to_emails => Faker::Internet.email,
                                            :from_email => "support@#{@account.full_domain}"
                                          },
                         :ticket_status => "",
                         :format => "js",
                         :showing => "notes",
                         :since_id => "197",
                         :ticket_id => test_ticket.display_id
        }
      rescue Exception => e
        test_ticket.reload
        test_ticket.notes.should be_empty
      end
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
    
    it "should add a private note to a ticket and change the status when showing activities" do
      note_body = Faker::Lorem.sentence(3)
      test_tkt = create_ticket({ :status => 2 })
      post :note, {  :helpdesk_note => { :note_body_attributes =>{ :body_html => "<div>#{note_body}</div>"},
                                          :private => "true",
                                          :source => "2"
                                        },
                     :ticket_status => "6", # waiting on customer - 6
                     :format => "js",
                     :showing => "activities",
                     :since_id => "197",
                     :ticket_id => test_tkt.display_id
                    }
      response.should render_template "helpdesk/notes/create.rjs"
      private_note = @account.tickets.find(test_tkt.id).notes.last
      private_note.full_text_html.should be_eql("<div>#{note_body}</div>")
      private_note.private.should be_true
      test_tkt.status.eql?(6)
    end

    it "should add a KBase article of ticket" do
     now = (Time.now.to_f*1000).to_i
     post :reply , { :reply_email => { :id => "support@#{@account.full_domain}"},
                     :helpdesk_note => { :cc_emails => ["kbase@#{@account.full_domain}"], 
                                         :note_body_attributes => {:body_html => "<div>#{now}</div>",
                                                                   :full_text_html => "<div>#{now}</div>"},
                                         :private => "0",
                                         :source => "0",
                                         :to_emails => "#{@agent.email}",
                                         :from_email => "support@#{@account.full_domain}",
                                         :bcc_emails => ""
                                        },
                     :ticket_status => "",
                     :ticket_id => @test_ticket.display_id,
                     :since_id => "-1",
                     :showing => "notes"
                   } 
      @account.solution_articles.find_by_title(@test_ticket.subject).should be_an_instance_of(Solution::Article)
    end

    it "should add a post to forum topic" do
      test_ticket = create_ticket({:status => 2 })
      category = create_test_category
      forum = create_test_forum(category)
      topic = create_test_topic(forum)
      create_ticket_topic_mapping(topic,test_ticket)
      now = (Time.now.to_f*1000).to_i
      body = "ticket topic note #{now}"
      post :reply , { :reply_email => { :id => "support@#{@account.full_domain}"},
                     :helpdesk_note => { :cc_emails => "", 
                                         :note_body_attributes => {:body_html => "<div>#{body}</div>",
                                                                   :full_text_html => "<div>#{body}</div>"},
                                         :private => "0",
                                         :source => "0",
                                         :to_emails => "#{@agent.email}",
                                         :from_email => "support@#{@account.full_domain}",
                                         :bcc_emails => ""
                                        },
                     :ticket_status => "",
                     :ticket_id => test_ticket.display_id,
                     :since_id => "-1",
                     :post_forums => "1",
                     :showing => "notes"
                   } 
      topic.reload
      topic.last_post.body.strip.should be_eql(body)
    end

    # Keep this last as ticket_cc is being changed
    it "should add a reply and alter reply_cc" do
      @test_ticket.cc_email = { :cc_emails => ["superman@justiceleague.com"], :fwd_emails => [], :reply_cc => ["superman@justiceleague.com"] }
      @test_ticket.save

      now = (Time.now.to_f*1000).to_i
      post :reply, { :reply_email => { :id => "support@#{@account.full_domain}" },
                     :helpdesk_note => { :note_body_attributes =>{ :body_html => "<div>#{now}</div>",
                                                                :full_text_html =>"<div>#{now}</div>"},
                                          :cc_emails => "batman@gothamcity.com, avengers@superheroes.com",
                                          :private => "false",
                                          :source => "0",
                                          :to_emails => Faker::Internet.email,
                                          :from_email => "support@#{@account.full_domain}"
                                        },
                     :ticket_status => "",
                     :format => "js",
                     :showing => "notes",
                     :ticket_id => @test_ticket.display_id
                    }
      latest_note = @account.tickets.find(@test_ticket.id).notes.last
      latest_note.notable.cc_email_hash[:reply_cc].should eql latest_note.cc_emails
    end
  end
    
  context "For API requests" do
    it "must add a note to the ticket via api" do
      request.host = @account.full_domain
      http_login(@agent)
      clear_json
      test_ticket = create_ticket({:status => 2 })
      ticket_id = test_ticket.display_id
      note_params = {
        :helpdesk_note => {
          :body => Faker::Lorem.words(15).join(" "),
          :private => false
        }
      }
      post :note, note_params.merge!({:format => 'json', :ticket_id => ticket_id }),:content_type => 'application/json'
      note_result = parse_json(response)
      expected = (response.status =~ /200 OK/) && compare(note_result['note'].keys,APIHelper::NOTE_ATTRIBS,{}).empty?
      expected.should be(true)
    end
  end

  describe "Reply to Mobihelp Ticket" do

    before(:each) do
      @mobihelp_ticket = create_ticket({:status => 2, :source => 8})
      log_in(@agent)
    end

    it "should reply to a mobihelp ticket" do
      now = (Time.now.to_f*1000).to_i    
      post :mobihelp, {
                     :helpdesk_note => { :note_body_attributes =>{ :body_html => "<div>#{now}</div>"},
                                          :private => "false",
                                          :source => "10"
                                        },
                     :ticket_status => "",
                     :format => "js",
                     :showing => "notes",
                     :since_id => "1",
                     :quoted_text_html => "",
                     :ticket_id => @mobihelp_ticket.display_id
                    }
      response.should render_template "helpdesk/notes/create.rjs"
      mobihelp_reply = @account.tickets.find(@mobihelp_ticket.id).notes.last
      mobihelp_reply.full_text_html.should be_eql("<div>#{now}</div>")
      mobihelp_reply.private.should be_false
    end

    it "should not reply to a mobihelp ticket if the source is invalid" do
      now = (Time.now.to_f*1000).to_i
      post :mobihelp, {
                     :helpdesk_note =>  { :note_body_attributes =>{:body_html => "<div>#{now}</div>"},
                                        :private => "false",
                                        :source => "100"
                                        },
                     :ticket_status => "",
                     :format => "js",
                     :showing => "notes",
                     :since_id => "1",
                     :quoted_text_html => "",
                     :ticket_id => @mobihelp_ticket.display_id
                    }
      mobihelp_reply = @account.tickets.find(@mobihelp_ticket.id).notes.last
      mobihelp_reply.should be_nil
    end
  end
end