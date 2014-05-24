require 'spec_helper'

describe Helpdesk::NotesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@user)
  end


  it "should create a note and go to index page(show activities)" do
    test_ticket = create_ticket({:status => 2 })
    body = "New note shown on index"
    post :create, :helpdesk_note => { :note_body_attributes => {:body_html => "<p>#{body}</p>"} },
                  :ticket_id => test_ticket.display_id

    test_ticket.reload
    test_ticket.notes.freshest(@account)[0].body.should =~ /#{body}/

    get :index, :v => 2, :ticket_id => test_ticket.display_id, :format => "json"
    response.body.should =~ /New note shown on index/

  end

  it "should create a note and go to index page(show activities) with xhr request" do
    test_ticket = create_ticket({:status => 2 })
    body = "New note shown on index"

    post :create, :helpdesk_note => { :note_body_attributes => {:body_html => "<p>#{body}</p>"} },
                  :ticket_id => test_ticket.display_id

    test_ticket.notes.freshest(@account)[0].body.should =~ /#{body}/
    xhr :get, :index, :v => 2, :ticket_id => test_ticket.display_id
    response.body.should =~ /New note shown on index/
    response.should render_template "helpdesk/tickets/show/_conversations.html.erb"
  end

  it "should edit a note " do
    test_ticket = create_ticket({:status => 2 })
    body = Faker::Lorem.paragraph
    ticket_note = create_note({:source => test_ticket.source,
                               :ticket_id => test_ticket.id,
                               :body => body,
                               :user_id => @user.id})
    get :edit, :ticket_id => test_ticket.display_id, :id => ticket_note.id
    response.body.should =~ /#{body}/
    response.should render_template "helpdesk/notes/_edit_note.html.erb"
  end

  it "should update a note " do
    test_ticket = create_ticket({:status => 2 })
    body = Faker::Lorem.paragraph
    ticket_note = create_note({:source => test_ticket.source,
                               :ticket_id => test_ticket.id,
                               :body => body,
                               :user_id => @user.id})

    updated_note_body = "Edited Note - #{Faker::Lorem.paragraph}"
    post :update, :helpdesk_note => {:source => test_ticket.source,
                                    :note_body_attributes => { :body_html => updated_note_body,
                                                               :id => ticket_note.id}},
                                    :id => ticket_note.id,
                                    :ticket_id => test_ticket.display_id
    flash[:notice].should be_eql("The note has been updated.")
    test_ticket.notes.last.body.should be_eql(updated_note_body)
  end

  it "should destroy a note " do
    test_ticket = create_ticket({:status => 2 })
    body = Faker::Lorem.paragraph
    ticket_note = create_note({:source => test_ticket.source,
                               :ticket_id => test_ticket.id,
                               :body => body,
                             :user_id => @user.id})
    test_ticket.notes.last.body.should be_eql(body)
    post :destroy, :id => ticket_note.id, :ticket_id => test_ticket.display_id
    test_ticket.notes.last.deleted.should be_eql(true)
  end
end
