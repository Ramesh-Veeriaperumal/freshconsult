require 'spec_helper'

describe Helpdesk::BulkTicketActionsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before do
    @account = create_test_account
    @user = add_test_agent(@account)
    @test_ticket = create_ticket({ :status => 2, :display_id => 90 }, create_group(@account, {:name => "Bulk"}))
    @group = @account.groups.first
    @request.host = @account.full_domain
    log_in(@user)
  end

  it "should perform bulk actions on selected tickets" do 
    test_ticket1 = create_ticket({ :status => 2 }, @group)
    test_ticket2 = create_ticket({ :status => 2 }, @group)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :update_multiple, { :helpdesk_note => { :note_body_attributes => { :body_html => "" }, 
                                                :private => "0", 
                                                :user_id => @user.id, 
                                                :source => "0"
                                              }, 
                            :helpdesk_ticket => { :ticket_type => "Feature Request", 
                                                :status => "4", 
                                                :priority => "4", 
                                                :group_id => create_group(@account, {:name => "Bulk123"}).id
                                              }, 
                            :ids => [@test_ticket.display_id, test_ticket1.display_id, test_ticket2.display_id]
                          }
    @account.tickets.find(@test_ticket).status.should be_eql(4)
    @account.tickets.find(test_ticket1).ticket_type.should be_eql("Feature Request")
    @account.tickets.find(test_ticket2).priority.should be_eql(4)
  end
end