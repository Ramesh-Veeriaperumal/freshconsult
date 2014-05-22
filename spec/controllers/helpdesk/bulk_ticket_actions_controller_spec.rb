require 'spec_helper'

describe Helpdesk::BulkTicketActionsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Bulk"}))
    @group = @account.groups.first
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
    @test_ticket.reload
    test_ticket1.reload
    test_ticket2.reload
    @test_ticket.status.should be_eql(4)
    test_ticket1.ticket_type.should be_eql("Feature Request")
    test_ticket2.priority.should be_eql(4)
  end
end
