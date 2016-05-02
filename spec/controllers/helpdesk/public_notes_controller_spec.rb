require 'spec_helper'

describe Public::NotesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    @test_ticket = create_ticket({ :status => 2 })
  end
  
  it "must add a note when the requester adds a note" do
    access_token = @test_ticket.get_access_token
    requester_email = @test_ticket.requester.email
    note_description = Faker::Lorem.paragraph
    post :create, {
                      :ticket_id => access_token,
                      :requester_email => requester_email,
                      :helpdesk_note => {
                        :note_body_attributes => {
                          :body_html => "<p>#{note_description}</p>"
                        }
                      }
    }
    note = @test_ticket.notes.last
    note.body.should be_eql(note_description)
  end
  
  it "must add a note when cc'd person adds a note" do
    cc_ppl = Faker::Internet.email
    @test_ticket.cc_email = {:cc_emails => [cc_ppl], :fwd_emails => [], :reply_cc => [cc_ppl]}
    @test_ticket.save
    
    access_token = @test_ticket.get_access_token
    note_description = Faker::Lorem.paragraph
    post :create, {
                      :ticket_id => access_token,
                      :requester_email => cc_ppl,
                      :helpdesk_note => {
                        :note_body_attributes => {
                          :body_html => "<p>#{note_description}</p>"
                        }
                      }
    }
    note = @test_ticket.notes.last
    note.body.should be_eql(note_description)
  end
  
  it "must throw an error when a person other than requester or cc'd person adds a note" do
    random_user = Faker::Internet.email
    access_token = @test_ticket.get_access_token
    note_description = Faker::Lorem.paragraph
    
    post :create, {
                      :ticket_id => access_token,
                      :requester_email => random_user,
                      :helpdesk_note => {
                        :note_body_attributes => {
                          :body_html => "<p>#{note_description}</p>"
                        }
                      }
    }
    note = @test_ticket.notes.last
    note.body.should_not == note_description
  end
end