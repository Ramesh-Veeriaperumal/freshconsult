require 'spec_helper'

describe Helpdesk::MergeTicketsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @group = create_group(@account, {:name => "Merge"})
    @target_ticket = create_ticket({ :status => 2}, @group)
  end

  before do
    login_admin
  end

  it "should merge tickets with private notes" do
    source_ticket1 = create_ticket({ :status => 2 }, @group)
    source_ticket2 = create_ticket({ :status => 2 }, @group)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    Resque.inline = true
    post :complete_merge, { :target => { :ticket_id => @target_ticket.display_id,
                                          :note => "Tickets with ids #{source_ticket1.display_id} and #{source_ticket2.display_id} are merged into this ticket.",
                                          :is_private => "true"
                                          },
                            :source_tickets => ["#{source_ticket1.display_id}", "#{source_ticket2.display_id}"],
                            :source => { :note => "This ticket is closed and merged into ticket #{@target_ticket.display_id}",
                                         :is_private => "true"
                                        },
                            :redirect_back => "true"
                          }
    Resque.inline = false
    flash[:notice] =~ /have been merged into the ticket/
    merged_tickets = @account.tickets.find([@target_ticket.id, source_ticket1.id, source_ticket2.id])
    last_target_note = merged_tickets[0].notes.last
    last_target_note.full_text.should be_eql("Tickets with ids #{source_ticket1.display_id} and #{source_ticket2.display_id} are merged into this ticket.")
    last_target_note.private.should be_true
    merged_tickets[1].status.should be_eql(5)
    last_source1_note = merged_tickets[1].notes.last
    last_source1_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source1_note.private.should be_true
    merged_tickets[2].status.should be_eql(5)
    last_source2_note = merged_tickets[2].notes.last
    last_source2_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source2_note.private.should be_true
  end

  it "should merge tickets with public notes" do
    source_ticket1 = create_ticket({ :status => 2 }, @group)
    source_ticket2 = create_ticket({ :status => 2 }, @group)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    Resque.inline = true
    post :complete_merge, { :target => { :ticket_id => @target_ticket.display_id,
                                          :note => "Tickets with ids #{source_ticket1.display_id} and #{source_ticket2.display_id} are merged into this ticket.",
                                          :is_private => "false"
                                          },
                            :source_tickets => ["#{source_ticket1.display_id}", "#{source_ticket2.display_id}"],
                            :source => { :note => "This ticket is closed and merged into ticket #{@target_ticket.display_id}",
                                         :is_private => "false"
                                        },
                            :redirect_back => "true"
                          }
    Resque.inline = false
    merged_tickets = @account.tickets.find([@target_ticket.id, source_ticket1.id, source_ticket2.id])
    last_target_note = merged_tickets[0].notes.last
    last_target_note.full_text.should be_eql("Tickets with ids #{source_ticket1.display_id} and #{source_ticket2.display_id} are merged into this ticket.")
    last_target_note.private.should be_false
    merged_tickets[1].status.should be_eql(5)
    last_source1_note = merged_tickets[1].notes.last
    last_source1_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source1_note.private.should be_false
    merged_tickets[2].status.should be_eql(5)
    last_source2_note = merged_tickets[2].notes.last
    last_source2_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source2_note.private.should be_false
  end

  it "should merge tickets with public notes for the source tickets" do
    source_ticket1 = create_ticket({ :status => 2 }, @group)
    source_ticket2 = create_ticket({ :status => 2 }, @group)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    Resque.inline = true
    post :complete_merge, { :target => { :ticket_id => @target_ticket.display_id,
                                          :note => "Tickets with ids #{source_ticket1.display_id} and #{source_ticket2.display_id} are merged into this ticket.",
                                          :is_private => "true"
                                          },
                            :source_tickets => ["#{source_ticket1.display_id}", "#{source_ticket2.display_id}"],
                            :source => { :note => "This ticket is closed and merged into ticket #{@target_ticket.display_id}",
                                         :is_private => "false"
                                        },
                            :redirect_back => "true"
                          }
    Resque.inline = false
    merged_tickets = @account.tickets.find([@target_ticket.id, source_ticket1.id, source_ticket2.id])
    last_target_note = merged_tickets[0].notes.last
    last_target_note.full_text.should be_eql("Tickets with ids #{source_ticket1.display_id} and #{source_ticket2.display_id} are merged into this ticket.")
    last_target_note.private.should be_true
    merged_tickets[1].status.should be_eql(5)
    last_source1_note = merged_tickets[1].notes.last
    last_source1_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source1_note.private.should be_false
    merged_tickets[2].status.should be_eql(5)
    last_source2_note = merged_tickets[2].notes.last
    last_source2_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source2_note.private.should be_false
  end
end
