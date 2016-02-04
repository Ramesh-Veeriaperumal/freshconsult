require 'spec_helper'

describe Helpdesk::ArchiveTicketsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @group = create_group(@account, {:name => "Test"})
    @ticket1 = create_ticket({ :status => 2}, @group)
    @ticket2 = create_ticket({ :status => 2}, @group)
    @ticket3 = create_ticket({ :status => 2}, @group)
    @account.features.send(:archive_tickets).create  
    Sidekiq::Testing.inline! do
      Archive::BuildCreateTicket.perform_async({:account_id => @account.id, :ticket_id => @ticket1.id})
    end
  end

  before(:each) do
   login_admin
  end

  it "should not fail to load, on 'sort by : due date' " do
    request.cookies[:wf_order] = "due_by".to_sym
    get 'index'
    response.should render_template "helpdesk/archive_tickets/index"
  end

  it "should not fail to load, on 'sort by : Customer Response' " do
    request.cookies[:wf_order] = "requester_responded_at".to_sym
    get 'index'
    response.should render_template "helpdesk/archive_tickets/index"
  end

  it "should not fail to load, on 'sort by : Agent Response' " do
    request.cookies[:wf_order] = "agent_responded_at".to_sym
    get 'index'
    response.should render_template "helpdesk/archive_tickets/index"
  end

end
