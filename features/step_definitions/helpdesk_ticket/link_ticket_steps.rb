Given(/^"([^"]*)" feature is enabled for the account$/) do |feature|
  @account.launch feature.to_sym
end

#============================================================================================================
# Scenario: Linking a ticket to a new Tracker ticket.

Given(/^a Ticket with subject "([^"]*)"$/) do |subject|
  @ticket = create_ticket({:subject => subject})
  @ticket.reload
end

When(/^I link the ticket "([^"]*)" by creating a new Tracker with the subject "([^"]*)"$/) do |subject, tracker_subject|
  ticket = @account.tickets.find_by_subject(subject)
  options = {:email => @agent.email, :subject => tracker_subject, :display_ids => "#{ticket.display_id}"}
  post(helpdesk_tickets_path, ticket_params_hash(options), @headers)
  @tracker =  Helpdesk::Ticket.last
end

Then(/^the Tracker "([^"]*)" should get created$/) do |tracker_subject|
  tracker = @account.tickets.find_by_subject(tracker_subject)
  assert tracker.tracker_ticket?, "Expected #{tracker.display_id} to be a Tracker" 
end

Then(/^I should get redirected to the ticket "([^"]*)"$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  assert_redirection helpdesk_ticket_path(ticket)
end

Then(/^the ticket "([^"]*)" should be linked to the tracker$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  assert_related_ticket(@tracker, ticket)
end

Then(/^the tracker should have "([^"]*)" related ticket "([^"]*)"$/) do |count, subject|
  ticket = @account.tickets.find_by_subject(subject)
  msg =  "Expected #{ticket.subject} linked to Tracker #{@tracker.subject}"
  assert_includes @tracker.associated_subsidiary_tickets("tracker").pluck(:display_id), ticket.display_id, msg
  assert_equal count.to_i, @tracker.related_tickets_count
end

#============================================================================================================
#Scenario: Linking a ticket to an existing tracker.

Given(/^a tracker ticket "([^"]*)"$/) do |tracker_subject|
  create_tracker({:subject => tracker_subject})
  @tracker = Helpdesk::Ticket.last
end

Given(/^the Tracker has these broadcast notes:$/) do |table|
  table.raw.each do |note_body| 
    create_broadcast_note(:ticket_id => @tracker.id, :body => note_body[0])
  end
end

When(/^I link the ticket "([^"]*)" to Tracker "([^"]*)"$/) do |subject, tracker_subject|
  ticket = @account.tickets.find_by_subject(subject)
  link_params = {:id => ticket.display_id, :tracker_id => @tracker.display_id}
  put link_helpdesk_ticket_path(ticket), link_params, @headers.merge('HTTP_REFERER' => helpdesk_ticket_path(ticket))
end

Then(/^the "([^"]*)" in the ticket "([^"]*)" should display "([^"]*)"$/) do |selector, subject, broadcast_message|
  ticket = @account.tickets.find_by_subject(subject)
  @response = get helpdesk_ticket_path(ticket), nil, @headers
  assert_select selector, Regexp.new(broadcast_message)
end

Then(/^the Tracker should have the ticket "([^"]*)" as its related$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  msg =  "Expected #{ticket.subject} linked to Tracker #{@tracker.subject}"
  assert_includes @tracker.associated_subsidiary_tickets("tracker").pluck(:display_id), ticket.display_id, msg
end

# ============================================================================================================
# Scenario: Linking multiple tickets to a new Tracker ticket.

Given(/^these tickets:$/) do |table|
  @ticket_ids = []
  table.raw.each do |subject|
    create_ticket({:subject => subject})
    @ticket_ids << @account.tickets.last.display_id
  end
end

When(/^I link these tickets by creating a new Tracker with the subject "([^"]*)"$/) do |tracker_subject|
  Sidekiq::Testing.inline! do
    options = {:email => @agent.email, :subject => tracker_subject, :display_ids => "#{@ticket_ids.join(',')}"}
    post helpdesk_tickets_path, ticket_params_hash(options), @headers
    @tracker = Helpdesk::Ticket.last
  end
end

Then(/^I should get redirected to "([^"]*)"$/) do |path|
  assert_redirection path
end

Then(/^the Tracker should get created with "([^"]*)" related tickets$/) do |count|
  assert_tracker @tracker
  assert_equal count.to_i, @tracker.related_tickets_count
end

Then(/^all the tickets should be linked to the Tracker "([^"]*)"$/) do |arg1|
  @ticket_ids.each { |id| assert_related_ticket(@tracker,@account.tickets.find_by_display_id(id)) }
end

# ============================================================================================================
# Scenario: Linking multiple tickets to an existing Tracker ticket.

When(/^I link the tickets to Tracker "([^"]*)"$/) do |tracker_subject|
  Sidekiq::Testing.inline! do
    link_params = {:id => 'multiple', :ids => @ticket_ids, :tracker_id => @tracker.display_id}
    put link_helpdesk_ticket_path('multiple'), link_params, @headers.merge('HTTP_REFERER' => helpdesk_tickets_path)
  end
end

Then(/^the related tickets count of the Tracker "([^"]*)" should get incremented by "([^"]*)"$/) do |tracker_subject, count|
  tracker = @account.tickets.find_by_subject(tracker_subject)
  assert_equal count.to_i, (tracker.related_tickets_count - 1)
end

#============================================================================================================
#Scenario: Unlink a Related ticket from its Tracker.

Given(/^a Related ticket with subject "([^"]*)" linked to a Tracker "([^"]*)"$/) do |subject, tracker_subject|
  @tracker = create_tracker({:subject => tracker_subject}, {:subject => subject})
end

When(/^I unlink the Related ticket "([^"]*)" from its Tracker$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  Sidekiq::Testing.inline! do
    unlink_params = {:id => ticket.display_id, :tracker => false, :tracker_id => @tracker.display_id}
    put unlink_helpdesk_ticket_path(ticket), unlink_params, @headers.merge('HTTP_REFERER' => helpdesk_ticket_path(ticket))
  end
end

Then(/^the related tickets for the Tracker "([^"]*)" should be decremented by "([^"]*)"$/) do |tracker_subject, count|
  @tracker = @account.tickets.find_by_subject(tracker_subject)
  assert_equal count.to_i, (1 - @tracker.related_tickets_count)
end

Then(/^the Related ticket "([^"]*)" should become a normal ticket$/) do |subject|
  @ticket = @account.tickets.find_by_subject(subject)
  assert_not_related @tracker, @ticket
end

Then(/^the unlinked ticket should not have the message "([^"]*)"$/) do |broadcast_message|
  get helpdesk_ticket_path(@ticket), nil, @headers
  assert_not_match Regexp.new(broadcast_message), last_response.body
end

#============================================================================================================
# Scenario: Deleting/Spamming a Tracker ticket.

Given(/^a Tracker ticket "([^"]*)" with the these related tickets:$/) do |tracker_subject, table|
  # table is a Cucumber::MultilineArgument::DataTable
  @related_ticket_ids = create_link_tickets(table.raw.size, tracker_subject, table.raw.flatten)
  @tracker = Helpdesk::Ticket.last
end

When(/^I Delete the Ticket "([^"]*)"$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  Sidekiq::Testing.inline! do
    delete helpdesk_ticket_path(ticket), nil, @headers
  end
end

Then(/^the Ticket "([^"]*)" should be moved to Trash Folder$/) do |subject|
  get '/helpdesk/tickets/filter/deleted', nil, @headers
  assert_match Regexp.new(subject), last_response.body
end

Then(/^the related tickets should be unlinked from the tracker and become normal tickets$/) do
  @related_ticket_ids.each do |display_id| 
    ticket = @account.tickets.find_by_display_id(display_id)
    assert_not_related(@tracker, ticket)
  end
end

When(/^I Spam the Ticket "([^"]*)"$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  Sidekiq::Testing.inline! do
    put spam_helpdesk_ticket_path(ticket), nil, @headers
  end
end

Then(/^the Ticket "([^"]*)" should be moved to SpamFolder$/) do |subject|
  get '/helpdesk/tickets/filter/spam', nil, @headers
  assert_match Regexp.new(subject), last_response.body
end

#============================================================================================================
# Scenario: Deleting/Spamming a Tracker ticket and undo it. 

When(/^I Undo the action for "([^"]*)"$/) do |subject|
  ticket = @account.tickets.find_by_subject(subject)
  put restore_helpdesk_ticket_path(ticket), nil, @headers
end

Then(/^the Tracker "([^"]*)" should have "([^"]*)" related tickets$/) do |tracker_subject, count|
  tracker = @account.tickets.find_by_subject(tracker_subject)
  assert_equal count.to_i, tracker.related_tickets_count
end

#============================================================================================================
#Scenario: Adding a Broadcast Message.

Given(/^a Related Ticket "([^"]*)" assigned to agent "([^"]*)"$/) do |subject, agent_mail|
  mail = Mail::Address.new(agent_mail)
  agent = add_agent(@account, {:name=>mail.name, :email => mail.address})
  ticket = create_ticket(:subject => subject, :responder_id => agent.id)
  link_to_tracker(@tracker, [ticket.display_id])
  @tracker.reload
end

When(/^I add a broadcast note "([^"]*)" to the Tracker$/) do |note_body|
  params = broadcast_note_params(:body => note_body, :ticket_id => @tracker.display_id)
  Sidekiq::Testing.fake! do
    post broadcast_helpdesk_ticket_conversations_path(@tracker), params, @headers
  end
  @broadcast_message = Helpdesk::BroadcastMessage.last
end

Then(/^the broadcast note should get added to the Tracker$/) do
  assert @tracker.notes.broadcast_notes.present?
end

Then(/^the "([^"]*)" should receive an email with the broadcast message$/) do |email|
  assert_equal 1, BroadcastMessages::NotifyBroadcastMessages.jobs.size
  Sidekiq::Testing.fake! do
    @account.make_current
    BroadcastMessages::NotifyBroadcastMessages.drain
  end
  assert_equal 1, BroadcastMessages::NotifyAgent.jobs.size
  args = BroadcastMessages::NotifyAgent.jobs.first["args"][0]
  assert_equal @tracker.display_id, args["tracker_display_id"]
  assert_equal email, args["recipients"]
  assert_equal @broadcast_message.id, args["broadcast_id"]
end

