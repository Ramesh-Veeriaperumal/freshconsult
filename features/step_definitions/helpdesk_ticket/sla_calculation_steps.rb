
Given(/^"([^"]*)" feature is launched for the account$/) do |feature|
  @account.launch feature.to_sym
end

Given(/^"([^"]*)" feature is present for the account$/) do |feature|
  @account.features.send(feature.to_sym).create
end

#============================================================================================================
# Scenario: Creating a ticket

When(/^I create a ticket with priority "([^"]*)", type "([^"]*)" and status "([^"]*)" at "([^"]*)"$/) do |priority, type, status, time|
  Timecop.freeze(get_datetime(time)) do
    options = {
                :subject => "sla testing #{Time.now.to_i}",
                :priority => TicketConstants::PRIORITY_KEYS_BY_TOKEN[:"#{priority}"],
                :status => Helpdesk::TicketStatus.status_keys_by_name(@account)["#{status}"],
                :ticket_type => type
              }
    post helpdesk_tickets_path, ticket_params_hash(options), @headers
    @ticket = @account.tickets.last
  end
end

#============================================================================================================
# Scenario: Updating a ticket's status from on state to off state

Given(/^a ticket created at "([^"]*)", priority "([^"]*)", type "([^"]*)" and status "([^"]*)"$/) do |time, priority, type, status|
  Timecop.freeze(get_datetime(time)) do
    @ticket = create_ticket({
                :subject => "sla testing #{Time.now.to_i}",
                :priority => TicketConstants::PRIORITY_KEYS_BY_TOKEN[:"#{priority}"],
                :status => Helpdesk::TicketStatus.status_keys_by_name(@account)["#{status}"],
                :ticket_type => type
              })
  end
end

Then(/^the ticket's due by should be "([^"]*)"$/) do |time|
  assert_equal get_datetime(time), @ticket.due_by
end

Then(/^the ticket's due by should be on "([^"]*)" at "([^"]*)"$/) do |day,time|
  assert_equal get_datetime(time,day), @ticket.due_by
end

Then(/^the ticket's first response due by should be "([^"]*)"$/) do |time|
  assert_equal get_datetime(time), @ticket.frDueBy
end

When(/^I update the ticket's status to "([^"]*)" at "([^"]*)"$/) do |status, time|
  @on_state = @ticket.ticket_states.on_state_time
  @due_by = @ticket.due_by
  @frDueBy = @ticket.frDueBy
  Timecop.freeze(get_datetime(time)) do
    put helpdesk_ticket_path(@ticket), { :helpdesk_ticket => { :status => Helpdesk::TicketStatus.status_keys_by_name(@account)["#{status}"] } }, @headers
    @ticket.reload
  end
end

Then(/^the ticket's time spent in on state should be "([^"]*)" "([^"]*)"$/) do |time, unit|
  assert_equal time.to_i.send("#{unit}"), @ticket.ticket_states.on_state_time
end

#============================================================================================================
# Scenario: Updating a ticket's status from off state to on state

Given(/^the ticket's status was updated to "([^"]*)" at "([^"]*)"$/) do |status, time|
  @ticket.remove_instance_variable(:@time_zone_now)
  Timecop.freeze(get_datetime(time)) do
    @ticket.update_attributes(:status => Helpdesk::TicketStatus.status_keys_by_name(@account)["#{status}"])
    @ticket.reload
  end
end

Then(/^the ticket's due by should be recalculated to "([^"]*)"$/) do |time|
  assert_equal get_datetime(time), @ticket.due_by
end

Then(/^the ticket's due by should be recalculated to "([^"]*)" at "([^"]*)"$/) do |day,time|
  assert_equal get_datetime(time,day), @ticket.due_by
end

Then(/^the ticket's first response due by should be recalculated to "([^"]*)"$/) do |time|
  assert_equal get_datetime(time), @ticket.frDueBy
end

#============================================================================================================
# Scenario: Updating a ticket's status from on state to on state

Then(/^the ticket's time spent in on state should not be recalculated$/) do
  assert_equal @on_state, @ticket.ticket_states.on_state_time
end

Then(/^the ticket's due by should not be recalculated$/) do
  assert_equal @due_by, @ticket.due_by
end

Then(/^the ticket's first response due by should not be recalculated$/) do
  assert_equal @frDueBy, @ticket.frDueBy
end

#============================================================================================================
# Scenario: Updating a ticket's priority

When(/^I update the ticket's priority to "([^"]*)" at "([^"]*)"$/) do |priority, time|
  Timecop.freeze(get_datetime(time)) do
    put helpdesk_ticket_path(@ticket), { :helpdesk_ticket => {
                                            :priority => TicketConstants::PRIORITY_KEYS_BY_TOKEN[:"#{priority}"],
                                            :status => @ticket.status
                                          }
                                        }, @headers
    @ticket.reload
  end
end

#============================================================================================================
# Scenario: Updating a ticket's priority

When(/^I update the ticket's priority to "([^"]*)" on "([^"]*)" at "([^"]*)"$/) do |priority, day, time|
  Timecop.freeze(get_datetime(time,day)) do
    put helpdesk_ticket_path(@ticket), { :helpdesk_ticket => {
        :priority => TicketConstants::PRIORITY_KEYS_BY_TOKEN[:"#{priority}"],
        :status => @ticket.status
    }
    }, @headers
    @ticket.reload
  end
end
#============================================================================================================
# Scenario: Updating a ticket's type

When(/^I update the ticket's type to "([^"]*)" at "([^"]*)"$/) do |type, time|
  Timecop.freeze(get_datetime(time)) do
    put helpdesk_ticket_path(@ticket), { :helpdesk_ticket => {
                                            :ticket_type => type,
                                            :status => @ticket.status
                                          }
                                        }, @headers
    @ticket.reload
  end
end

#============================================================================================================
# Scenario: Updating a ticket's source

When(/^I update the ticket's source to "([^"]*)" at "([^"]*)"$/) do |source, time|
  Timecop.freeze(get_datetime(time)) do
    put helpdesk_ticket_path(@ticket), { :helpdesk_ticket => {
                                            :source => Helpdesk::Source.default_ticket_source_keys_by_token[:"#{source}"],
                                            :status => @ticket.status
                                          }
                                        }, @headers
    @ticket.reload
  end
end

#============================================================================================================
# Scenario: Updating a ticket's company

When(/^I update the ticket's company to "([^"]*)" at "([^"]*)"$/) do |company, time|
  company = @account.companies.where(:name => company).first
  requester = add_new_user(@account)
  requester.company_id = company.id
  Timecop.freeze(get_datetime(time)) do
    put helpdesk_ticket_path(@ticket), { :helpdesk_ticket => {
                                            :requester_id => requester.id,
                                            :status => @ticket.status
                                          }
                                        }, @headers
    @ticket.reload
  end
end

#============================================================================================================
# Scenario: Updating a ticket's group

When(/^I update the ticket's group to "([^"]*)" at "([^"]*)"$/) do |group, time|
  group = @account.groups.where(:name => group).first
  Timecop.freeze(get_datetime(time)) do
    put helpdesk_ticket_path(@ticket), { :helpdesk_ticket => {
                                            :group_id => group.id,
                                            :status => @ticket.status
                                          }
                                        }, @headers
    @ticket.reload
  end
end

#============================================================================================================
# Scenario: Updating a ticket's internal group

When(/^I update the ticket's internal group to "([^"]*)" at "([^"]*)"$/) do |group, time|
  group = create_group(@account, { :name => group })
  status = @account.ticket_statuses.where(:status_id => @ticket.status).first
  status.group_ids = [group.id]
  status.save
  @on_state = @ticket.ticket_states.on_state_time
  @due_by = @ticket.due_by
  @frDueBy = @ticket.frDueBy
  Timecop.freeze(get_datetime(time)) do
    put helpdesk_ticket_path(@ticket), { :helpdesk_ticket => {
                                            :internal_group_id => group.id,
                                            :status => @ticket.status
                                          }
                                        }, @headers
    @ticket.reload
  end
end

#============================================================================================================
# Scenario: Updating a ticket's group to a group with different business hours

Given(/^a ticket created at "([^"]*)", priority "([^"]*)", type "([^"]*)", status "([^"]*)" and group "([^"]*)"$/) do |time, priority, type, status, group|
  group = @account.groups.where(:name => group).first
  Timecop.freeze(get_datetime(time)) do
    @ticket = create_ticket({
                :subject => "sla testing #{Time.now.to_i}",
                :priority => TicketConstants::PRIORITY_KEYS_BY_TOKEN[:"#{priority}"],
                :status => Helpdesk::TicketStatus.status_keys_by_name(@account)["#{status}"],
                :ticket_type => type
              }, group)
  end
end

#============================================================================================================
# Scenario: Updating a ticket's group to a group with different business hours

Given(/^a ticket created on "([^"]*)" at "([^"]*)", priority "([^"]*)", type "([^"]*)", status "([^"]*)" and group "([^"]*)"$/) do |day, time, priority, type, status, group|
  group = @account.groups.where(:name => group).first
  Timecop.freeze(get_datetime(time,day)) do
    @ticket = create_ticket({
                                :subject => "sla testing #{Time.now.to_i}",
                                :priority => TicketConstants::PRIORITY_KEYS_BY_TOKEN[:"#{priority}"],
                                :status => Helpdesk::TicketStatus.status_keys_by_name(@account)["#{status}"],
                                :ticket_type => type
                            }, group)
  end
end

#============================================================================================================
# Scenario: Updating a ticket after first response has been made

Given(/^the ticket's first response was made at "([^"]*)"$/) do |time|
  @frDueBy = @ticket.frDueBy
  Timecop.freeze(get_datetime(time)) do
    Sidekiq::Testing.inline! do
      @note = create_note({:ticket_id => @ticket.id})
    end
  end
end
