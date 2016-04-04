require 'spec_helper'

describe Helpdesk::BulkTicketActionsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before do
    @group_name="Bulk - #{Time.now}"
    @test_ticket = create_ticket({ :status => 2}, create_group(@account, {:name => @group_name}))
    @group = @account.groups.find_by_name(@group_name)
    log_in(@agent)
  end

# Bulk actions - restricted access

  it "should not allow restricted agent to update ticket properties" do
    restricted_user = add_agent(@account, { :name => Faker::Name.name,
                                            :email => Faker::Internet.email,
                                            :active => 1,
                                            :role => 1,
                                            :agent => 1,
                                            :ticket_permission => 3,
                                            :role_ids => ["#{@account.roles.first.id}"] })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @agent.id)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>restricted_user.id)
    group_id=create_group(@account, {:name => "Bulk123"}).id
    log_in(restricted_user)
    ticket_reply_notes=Faker::Lorem.paragraph
    @request.env['HTTP_REFERER'] = 'sessions/new'
    Sidekiq::Testing.inline!
    initial_count = global_agent_ticket.notes.count
    put :update_multiple, { :helpdesk_note => { :note_body_attributes => { :body_html => "<p> #{ticket_reply_notes} <p>" },
                                                :private => "0",
                                                :user_id => restricted_user.id,
                                                :source => "0"
                                              },
                            :helpdesk_ticket => { :ticket_type => "Feature Request",
                                                :status => "4",
                                                :priority => "4",
                                                :group_id => group_id
                                              },
                            :ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id] }
    Sidekiq::Testing.disable!
    global_ticket=@account.tickets.find(global_agent_ticket.id)
    global_ticket.status.should be_eql(2)
    global_ticket.ticket_type.should be_eql(global_agent_ticket.ticket_type)
    global_ticket.priority.should be_eql(global_agent_ticket.priority)
    global_ticket.group_id.should be_eql(global_agent_ticket.group_id)
    updated_count = global_agent_ticket.notes.count
    updated_count.should be_eql(initial_count)
    restricted_ticket=@account.tickets.find(restricted_agent_ticket.id)
    restricted_ticket.status.should be_eql(4)
    restricted_ticket.ticket_type.should be_eql("Feature Request")
    restricted_ticket.priority.should be_eql(4)
    restricted_ticket.group_id.should be_eql(group_id)
    restricted_ticket.notes.last.body.should be_eql(ticket_reply_notes)
  end

  # Bulk actions - Group access

  it "should not allow group agent to update ticket properties" do
    test_group = create_group(@account, {:name => "Group-Bulk -Test - #{Time.now}"})
    group_user = add_agent(@account, { :name => Faker::Name.name,
                                            :email => Faker::Internet.email,
                                            :active => 1,
                                            :role => 1,
                                            :agent => 1,
                                            :ticket_permission => 2,
                                            :role_ids => ["#{@account.roles.first.id}"] ,
                                            :group_id => test_group.id})
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @agent.id)

    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>group_user.id)

    group_agent_ticket =create_ticket({ :status => 2 },test_group)
    group_agent_ticket.update_attributes(:responder_id => @agent.id)
    group_id=create_group(@account, {:name => "Bulk123"}).id
    log_in(group_user)
    ticket_reply_notes=Faker::Lorem.paragraph
    @request.env['HTTP_REFERER'] = 'sessions/new'
    Sidekiq::Testing.inline!
    put :update_multiple, { :helpdesk_note => { :note_body_attributes => { :body_html => "<p> #{ticket_reply_notes} <p>" },
                                                :private => "0",
                                                :user_id => group_user.id,
                                                :source => "0"
                                              },
                            :helpdesk_ticket => { :ticket_type => "Feature Request",
                                                :status => "4",
                                                :priority => "4",
                                                :group_id => group_id
                                              },
                            :ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id,group_agent_ticket.display_id] }
    Sidekiq::Testing.disable!
    global_ticket=@account.tickets.find(global_agent_ticket.id)
    global_ticket.status.should be_eql(2)
    global_ticket.ticket_type.should be_eql(global_agent_ticket.ticket_type)
    global_ticket.priority.should be_eql(global_agent_ticket.priority)
    global_ticket.group_id.should be_eql(global_agent_ticket.group_id)
    global_ticket.notes.last.should be_nil
    restricted_ticket=@account.tickets.find(restricted_agent_ticket.id)
    restricted_ticket.status.should be_eql(4)
    restricted_ticket.ticket_type.should be_eql("Feature Request")
    restricted_ticket.priority.should be_eql(4)
    restricted_ticket.group_id.should be_eql(group_id)
    restricted_ticket.notes.last.body.should be_eql(ticket_reply_notes)
    group_ticket=@account.tickets.find(group_agent_ticket.id)
    group_ticket.status.should be_eql(4)
    group_ticket.ticket_type.should be_eql("Feature Request")
    group_ticket.priority.should be_eql(4)
    group_ticket.group_id.should be_eql(group_id)
    group_ticket.notes.last.body.should be_eql(ticket_reply_notes)
  end
end
