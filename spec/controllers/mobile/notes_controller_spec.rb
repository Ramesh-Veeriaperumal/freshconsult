require 'spec_helper'

describe Helpdesk::NotesController do
  self.use_transactional_fixtures = false

  before(:each) do
    api_login
  end

  it "should get notes json" do
    test_ticket = create_ticket({:status => 2 })
    body_one = Faker::Lorem.paragraph
    ticket_note_one = create_note({:source => test_ticket.source,
                               :ticket_id => test_ticket.id,
                               :body => body_one,
                             :user_id => @agent.id})
    body_two = Faker::Lorem.paragraph
    ticket_note_two = create_note({:source => test_ticket.source,
                               :ticket_id => test_ticket.id,
                               :body => body_two,
                             :user_id => @agent.id})
    get :index, {"before_id"=>"#{ticket_note_two.id}", "format"=>"json", "controller"=>"helpdesk/notes", "action"=>"index", "ticket_id"=>"#{test_ticket.display_id}"}
    json_response[0]["note"]["id"].should be_eql(ticket_note_one.id)
    json_response[0]["note"].should include("user","schema_less_note","source","id","private","formatted_created_at","body_html")
    json_response[0]["note"]["user"].should include("name","id","email","avatar_url")
  end

  it "should destroy a note " do
    test_ticket = create_ticket({:status => 2 })
    body = Faker::Lorem.paragraph
    ticket_note = create_note({:source => test_ticket.source,
                               :ticket_id => test_ticket.id,
                               :body => body,
                             :user_id => @agent.id})
    post :destroy, { :format => "json", :id => ticket_note.id, :ticket_id => test_ticket.display_id }
    test_ticket.notes.last.deleted.should be_eql(true)
    json_response.should include("success")
    json_response["success"].should be true
  end

  # it "should restore a note" do
  #   test_ticket = create_ticket({:status => 2 })
  #   body = Faker::Lorem.paragraph
  #   ticket_note = create_note({:source => test_ticket.source,
  #                              :ticket_id => test_ticket.id,
  #                              :body => body,
  #                            :user_id => @agent.id})
  #   test_ticket.notes.last.id.should be_eql(test_ticket.id)
  #   post :destroy, { :format => "json", :id => ticket_note.id, :ticket_id => test_ticket.display_id }
  #   test_ticket.notes.last.deleted.should be_eql(true)
  #   post :restore, { :format => "json" , :id => ticket_note.id}
  # end

end
