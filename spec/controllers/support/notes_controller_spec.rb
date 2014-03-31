require 'spec_helper'

describe Support::NotesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = Factory.build(:user)
    @user.save
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = 'sessions/new'
    log_in(@user)
  end

  it "should re-open a closed ticket after a customer reply" do
    test_ticket = create_ticket({:requester_id => @user.id, :status => 5 }, create_group(@account, {:name => "Support"}))
    Resque.inline = true
    post :create, :helpdesk_note => { :note_body_attributes => {:body_html => "<p>New note</p>"} }, 
                  :ticket_id => test_ticket.display_id
    Resque.inline = false
    reopened_ticket = @account.tickets.find(test_ticket.id)
    reopened_ticket.status.should be_eql(2)
    reopened_ticket.notes.last.full_text_html.should be_eql("<div>New note</div>")
  end
end