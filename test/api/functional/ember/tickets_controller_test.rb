require_relative '../../test_helper'
class Ember::TicketsControllerTest < ActionController::TestCase
  include TicketsTestHelper

  def wrap_cname(params)
    { ticket: params }
  end

  def ticket_params_hash
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                    priority: 2, status: 3, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                    due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: @create_group.id }
    params_hash
  end

  def test_bulk_delete_with_no_params
    put :bulk_delete, construct_params({ version: 'private' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('ids', :missing_field)])
  end

  def test_bulk_delete_with_invalid_ids
    ticket_ids = []
    rand(2..10).times do
      ticket_ids << create_ticket(ticket_params_hash).display_id
    end
    invalid_ids = [ticket_ids[0] + 20, ticket_ids[0] + 30]
    ids_to_delete = [*ticket_ids, *invalid_ids]
    put :bulk_delete, construct_params({ version: 'private' }, {ids: ids_to_delete})
    errors = {}
    invalid_ids.each { |id| errors[id] = :"is invalid" }
    match_json(partial_success_response_pattern(ticket_ids, errors))
    assert_response 202
  end

  def test_bulk_delete_with_valid_ids
    ticket_ids = []
    rand(2..10).times do
      ticket_ids << create_ticket(ticket_params_hash).display_id
    end
    put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
    assert_response 205
  end

  def test_bulk_delete_with_errors_in_deletion
    tickets = []
    rand(2..10).times do
      tickets << create_ticket(ticket_params_hash)
    end
    ids_to_delete = tickets.map(&:display_id)
    Helpdesk::Ticket.any_instance.stubs(:save).returns(false)
    put :bulk_delete, construct_params({ version: 'private' }, {ids: ids_to_delete})
    errors = {}
    ids_to_delete.each { |id| errors[id] = :unable_to_perform }
    match_json(partial_success_response_pattern([], errors))
    assert_response 202
  end

  def test_bulk_delete_tickets_without_access
    ticket_ids = []
    rand(2..10).times do
      ticket_ids << create_ticket(ticket_params_hash).display_id
    end
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
    errors = {}
    ticket_ids.each { |id| errors[id] = :"is invalid" }
    match_json(partial_success_response_pattern([], errors))
    assert_response 202
  end

  def test_bulk_delete_tickets_with_group_access
    params = ticket_params_hash
    @agent.agent.ticket_permission = Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets]
    @agent.group_ids << @create_group.id
    @agent.save
    ticket_ids = []
    rand(2..10).times do
      ticket_ids << create_ticket(params).display_id
    end
    put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
    assert_response 205
  end

  def test_bulk_delete_tickets_with_assigned_access
    @agent.agent.ticket_permission = Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]
    @agent.save
    ticket_ids = []
    rand(2..10).times do
      ticket_ids << create_ticket(ticket_params_hash).display_id
    end
    put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
    assert_response 205
  end

  def test_bulk_spam_with_no_params
    put :bulk_spam, construct_params({ version: 'private' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('ids', :missing_field)])
  end

  def test_bulk_spam_with_invalid_ids
    ticket_ids = []
    rand(2..10).times do
      ticket_ids << create_ticket(ticket_params_hash).display_id
    end
    invalid_ids = [ticket_ids[0] + 20, ticket_ids[0] + 30]
    ids_list = [*ticket_ids, *invalid_ids]
    put :bulk_spam, construct_params({ version: 'private' }, {ids: ids_list})
    errors = {}
    invalid_ids.each { |id| errors[id] = :"is invalid" }
    match_json(partial_success_response_pattern(ticket_ids, errors))
    assert_response 202
  end

  def test_bulk_spam_with_valid_ids
    ticket_ids = []
    rand(2..10).times do
      ticket_ids << create_ticket(ticket_params_hash).display_id
    end
    put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
    assert_response 205
  end

  def test_bulk_spam_with_errors
    tickets = []
    rand(2..10).times do
      tickets << create_ticket(ticket_params_hash)
    end
    ids_list = tickets.map(&:display_id)
    Helpdesk::Ticket.any_instance.stubs(:save).returns(false)
    put :bulk_spam, construct_params({ version: 'private' }, {ids: ids_list})
    errors = {}
    ids_list.each { |id| errors[id] = :unable_to_perform }
    match_json(partial_success_response_pattern([], errors))
    assert_response 202
  end

  def test_bulk_spam_tickets_without_access
    ticket_ids = []
    rand(2..10).times do
      ticket_ids << create_ticket(ticket_params_hash).display_id
    end
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
    errors = {}
    ticket_ids.each { |id| errors[id] = :"is invalid" }
    match_json(partial_success_response_pattern([], errors))
    assert_response 202
  end

  def test_bulk_spam_tickets_with_group_access
    params = ticket_params_hash
    @agent.agent.ticket_permission = Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets]
    @agent.group_ids << @create_group.id
    @agent.save
    ticket_ids = []
    rand(2..10).times do
      ticket_ids << create_ticket(params).display_id
    end
    put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
    assert_response 205
  end

  def test_bulk_spam_tickets_with_assigned_access
    @agent.agent.ticket_permission = Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]
    @agent.save
    ticket_ids = []
    rand(2..10).times do
      ticket_ids << create_ticket(ticket_params_hash).display_id
    end
    put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
    assert_response 205
  end

end
