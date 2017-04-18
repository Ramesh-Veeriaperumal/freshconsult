Given(/^"([^"]*)" feature is enabled for the accounts$/) do |feature|
  @account.launch feature.to_sym
  #@account.add_feature feature.to_sym
end

Given(/^a ticket with subject "([^"]*)"$/) do |subject|
  @ticket = create_ticket({:subject => subject})
  @ticket.reload
end

When(/^we create child ticket with the subject "([^"]*)" for a ticket "([^"]*)"$/) do |child_subj, subject|
  prt_ticket = @account.tickets.find_by_subject(subject)
  options = {:email => @agent.email, :subject => child_subj, :assoc_parent_id => "#{prt_ticket.display_id}"}
  post(helpdesk_tickets_path, ticket_params_hash(options), @headers)
  @child_tkt =  Helpdesk::Ticket.last
end

Then(/^child ticket "([^"]*)" should get created$/) do |subject|
  child = @account.tickets.find_by_subject(subject)
  assert child.child_ticket?, "Expected #{child.display_id} to be a child tkt"
end

Then(/^the ticket "([^"]*)" should associated as a parent ticket$/) do |subject|
  @prt_ticket = @account.tickets.find_by_subject(subject)
  assert @prt_ticket.assoc_parent_ticket?, "Expected #{@prt_ticket.display_id} to be a parent tkt"
end

Then(/^we should get redirected to the ticket "([^"]*)"$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  assert_redirection helpdesk_ticket_path(ticket)
end

Then(/^the ticket "([^"]*)" should be linked to the parent "([^"]*)"$/) do |child_subj, prt_subj|
  assert_equal  @prt_ticket.display_id, @child_tkt.associates.first
end

Then(/^the parent should have "([^"]*)" child ticket "([^"]*)"$/) do |count, prt_subj|
  assert_equal  count.to_i, @prt_ticket.child_tkts_count
end

Given(/^a parent with subject "([^"]*)"$/) do |subject|
  @prt_ticket = create_parent_ticket({:subject => subject})
  @prt_ticket.reload
end

When(/^we create child ticket with the subjt "([^"]*)" for a ticket "([^"]*)"$/) do |child_subj, subject|
  @agent.make_current
  options = {:email => @agent.email, :subject => child_subj, :assoc_parent_id => "#{@prt_ticket.display_id}"}
  post(helpdesk_tickets_path, ticket_params_hash(options), @headers)
  @child_tkt =  Helpdesk::Ticket.last
end

Then(/^child ticket should get created$/) do
  assert @child_tkt.child_ticket?, "Expected #{@child_tkt.display_id} to be a child ticket"
end

Then(/^the parent should have "([^"]*)" child tickets$/) do |count|
  assert_equal  count.to_i, @prt_ticket.child_tkts_count
end

Given(/^a parent ticket with subject "([^"]*)" and the status resolved$/) do |subject|
  @prt_ticket = create_parent_ticket({:subject => subject, :status => Helpdesk::Ticketfields::TicketStatus::CLOSED})
  @prt_ticket.reload
end

When(/^we create child ticket with the subject "([^"]*)" for a prt ticket "([^"]*)"$/) do |child_subj, subj|
  options = {:email => @agent.email, :subject => child_subj, :assoc_parent_id => "#{@prt_ticket.display_id}"}
  Sidekiq::Testing.inline! do
    post(helpdesk_tickets_path, ticket_params_hash(options), @headers)
  end
  @child_tkt = Helpdesk::Ticket.last
end

Then(/^child ticket "([^"]*)" should get created with unresolved status$/) do |subject|
  assert @child_tkt.child_ticket?, "Expected #{@child_tkt.display_id} to be a child ticket"
  assert_equal @prt_ticket.display_id, @child_tkt.associates_rdb.to_i
end

Then(/^the parent ticket "([^"]*)" should get reopened$/) do |subject|
  @prt_ticket.reload
  assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, @prt_ticket.status
end

Given(/^parent ticket with subject "([^"]*)" and child ticket with the subject "([^"]*)"$/) do |child_subj, subject|
  @prt_ticket = create_parent_ticket({:subject => subject, :status => Helpdesk::Ticketfields::TicketStatus::CLOSED})
  @prt_ticket.reload
  @child_ticket = @prt_ticket.associated_subsidiary_tickets("assoc_parent").first
end

#Any unresolved status
When(/^we reopen child ticket with the subject "([^"]*)"$/) do |arg1|
  params = {:id => @child_ticket.display_id,
            :helpdesk_ticket => {:status => Helpdesk::Ticketfields::TicketStatus::OPEN}
          }
  Sidekiq::Testing.inline! do
    put update_ticket_properties_helpdesk_ticket_path(@child_ticket), params, @headers.merge('HTTP_REFERER' => helpdesk_ticket_path(@child_ticket))
  end
  @child_ticket.reload
end

Then(/^child tkt "([^"]*)" should get reopened$/) do |subj|
  assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, @child_ticket.status
end

Then(/^the parent tkt "([^"]*)" should get reopened$/) do |subj|
  @prt_ticket.reload
  assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, @prt_ticket.status
end

Given(/^a parent tkt with subject "([^"]*)"$/) do |subject|
  @prt_ticket = create_parent_ticket({:subject => subject, :status => Helpdesk::Ticketfields::TicketStatus::CLOSED})
  @prt_ticket.reload
end

When(/^we create child ticket with the subject "([^"]*)" and status resolved for a ticket "([^"]*)"$/) do |child_subj, subject|
  options = {:email => @agent.email, :subject => child_subj, :assoc_parent_id => "#{@prt_ticket.display_id}",
             :status => Helpdesk::Ticketfields::TicketStatus::RESOLVED}
  Sidekiq::Testing.inline! do
    post(helpdesk_tickets_path, ticket_params_hash(options), @headers)
  end
  @child_tkt = Helpdesk::Ticket.last
end

Then(/^child ticket should get created "([^"]*)"$/) do |subject|
  assert @child_tkt.child_ticket?, "Expected #{@child_tkt.display_id} to be a child tkt"
  assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, @child_tkt.status
end

Then(/^the parent ticket "([^"]*)" should not get reopened$/) do |subj|
  @prt_ticket.reload
  assert_equal Helpdesk::Ticketfields::TicketStatus::CLOSED, @prt_ticket.status
end

Given(/^a parent ticket with subject "([^"]*)" and a child ticket "([^"]*)" with unresolved status$/) do |subj, child_subj|
  @prt_ticket = create_parent_ticket({:subject => subj, :status=>Helpdesk::Ticketfields::TicketStatus::PENDING,
                                      :priority => TicketConstants::PRIORITY_KEYS_BY_TOKEN[:medium]})
  @prt_ticket.reload
end

When(/^we trying closing a parent ticket "([^"]*)" which has unresolved child ticket "([^"]*)"$/) do |arg1, arg2|
  assert_equal Helpdesk::Ticketfields::TicketStatus::PENDING, @prt_ticket.status
  assert_equal TicketConstants::PRIORITY_KEYS_BY_TOKEN[:medium], @prt_ticket.priority
  params = {:id => @prt_ticket.display_id,
            :helpdesk_ticket => {:status => Helpdesk::Ticketfields::TicketStatus::CLOSED,
                                 :priority => TicketConstants::PRIORITY_KEYS_BY_TOKEN[:urgent]}
          }
  Sidekiq::Testing.inline! do
    put update_ticket_properties_helpdesk_ticket_path(@prt_ticket), params, @headers.merge('HTTP_REFERER' => helpdesk_ticket_path(@prt_ticket))
  end
  @prt_ticket.reload
end

Then(/^the parent ticket should not get closed$/) do
  assert_equal Helpdesk::Ticketfields::TicketStatus::PENDING, @prt_ticket.status
  assert_equal TicketConstants::PRIORITY_KEYS_BY_TOKEN[:urgent], @prt_ticket.priority
end

Given(/^a parent tkt "([^"]*)" with these child tickets:$/) do |parent_subject, table|
  # table is a Cucumber::MultilineArgument::DataTable
  @child_ticket_ids = create_multiple_pc_tickets(table.raw.size, parent_subject, table.raw.flatten)
end

When(/^I Delete the Parent Tkt "([^"]*)"$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  Sidekiq::Testing.inline! do
    delete helpdesk_ticket_path(ticket), nil, @headers
  end
end

Then(/^the Parent Ticket "([^"]*)" should be moved to Trash Folder$/) do |parent_subject|
  prt_ticket =  @account.tickets.find_by_subject(parent_subject)
  get '/helpdesk/tickets/filter/deleted', nil, @headers
  assert_match Regexp.new(parent_subject), last_response.body
  assert !prt_ticket.assoc_parent_ticket?, "Expected #{prt_ticket.display_id} not to be a Parent ticket"
end

Then(/^the child tickets should be unlinked from the parent and become normal tkts$/) do
  @child_ticket_ids.each do |display_id|
    ticket = @account.tickets.find_by_display_id(display_id)
    assert !ticket.child_ticket?, "Expected #{ticket.display_id} not to be a Child ticket"
    assert_nil ticket.associated_prime_ticket("child")
  end
end

When(/^I Spam the Parent Tkt "([^"]*)"$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  Sidekiq::Testing.inline! do
    put spam_helpdesk_ticket_path(ticket), nil, @headers
  end
end

Then(/^the Parent Ticket "([^"]*)" should be moved to SpamFolder$/) do |subject|
  get '/helpdesk/tickets/filter/spam', nil, @headers
  assert_match Regexp.new(subject), last_response.body
end

When(/^I Undo the action for Parent tkt "([^"]*)"$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  put restore_helpdesk_ticket_path(ticket), nil, @headers
end

Then(/^the Parent tkt "([^"]*)" should have "([^"]*)" child tickets$/) do |prt_subj, count|
  prt_ticket = @account.tickets.find_by_subject(prt_subj)
  assert_equal count.to_i, prt_ticket.child_tkts_count.to_i
end

When(/^I Delete the Child Ticket "([^"]*)"$/) do |subject|
  child_ticket = @account.tickets.find_by_subject(subject)
  Sidekiq::Testing.inline! do
    delete helpdesk_ticket_path(child_ticket), nil, @headers
  end
end

Then(/^the Child Ticket "([^"]*)" should be moved to Trash Folder$/) do |subject|
  get '/helpdesk/tickets/filter/deleted', nil, @headers
  assert_match Regexp.new(subject), last_response.body
end

Then(/^the Child ticket "([^"]*)" should become a normal ticket$/) do |child_subj|
  ticket = @account.tickets.find_by_subject(child_subj)
  assert !ticket.child_ticket?, "Expected #{ticket.display_id} not to be a Child ticket"
  assert_nil ticket.associated_prime_ticket("child")
end

Then(/^the child tickets for the Parent "([^"]*)" should be decremented by "([^"]*)"$/) do |prt_subj, count|
  prt_ticket = @account.tickets.find_by_subject(prt_subj)
  assert_equal count.to_i, (prt_ticket.child_tkts_count - 1)
end

When(/^I Spam the Child Ticket "([^"]*)"$/) do |subject|
  child_ticket = @account.tickets.find_by_subject(subject)
  Sidekiq::Testing.inline! do
    put spam_helpdesk_ticket_path(child_ticket), nil, @headers
  end
end

Then(/^the Child Ticket "([^"]*)" should be moved to SpamFolder$/) do |subject|
  get '/helpdesk/tickets/filter/spam', nil, @headers
  assert_match Regexp.new(subject), last_response.body
end

When(/^I Undo the action for tkt "([^"]*)"$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  put restore_helpdesk_ticket_path(ticket), nil, @headers
end

Given(/^a parent tkt "([^"]*)" with (\d+) child tickets$/) do |prt_subj, count|
  @child_ticket_ids = create_multiple_pc_tickets(count.to_i, prt_subj)
  @prt_ticket = @account.tickets.find_by_subject(prt_subj)
end

Then(/^try creating one more child ticket "([^"]*)" for the parent ticket$/) do |child_subj|
  options = {:email => @agent.email, :subject => child_subj, :assoc_parent_id => "#{@prt_ticket.display_id}"}
  @response = post(helpdesk_tickets_path, ticket_params_hash(options), @headers)
end

Then(/^the child ticket "([^"]*)" shouldn't be created$/) do |subject|
  error_msg = "Failed to create child to the parent ticket as it already reached the limit of 10 tickets."
  assert_match Regexp.new(error_msg), last_response.body
end