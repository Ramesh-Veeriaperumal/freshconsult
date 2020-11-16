# frozen_string_literal: true

require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require 'webmock/minitest'

class Tickets::BulkActionsControllerTest < ActionController::TestCase
  include ApiTicketsTestHelper
  include ArchiveTicketTestHelper
  include BulkApiJobsHelper
  include AdvancedTicketScopes

  SAMPLE_TICKET_ID = 31

  def wrap_cname(params)
    { bulk_action: params }
  end

  def setup
    super
    @account.enable_setting :archive_tickets_api
  end

  def rollback
    @account.disable_setting :archive_tickets_api
  end

  def ticket_params_hash
    cc_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                    priority: 2, status: 3, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                    due_by: 14.days.since.iso8601, fr_due_by: 1.day.since.iso8601, group_id: @create_group.id }
    params_hash
  end

  def test_archive_with_disable_archive_enabled
    # need to stub instead of destroy
    Account.any_instance.stubs(:disable_archive_enabled?).returns(true)
    params = { archive_days: 0, ids: [SAMPLE_TICKET_ID] }
    post :bulk_archive, construct_params(params)
    assert_response 403
    Account.any_instance.unstub(:disable_archive_enabled?)
  end

  def test_archive_without_archive_tickets_api
    @account.disable_setting :archive_tickets_api
    params = { archive_days: 0, ids: [SAMPLE_TICKET_ID] }
    post :bulk_archive, construct_params(params)
    assert_response 403
  end

  def test_archive_with_invalid_parameter
    enable_archive_tickets do
      params = { archive_days: 0, ids: [SAMPLE_TICKET_ID], article: 1 }
      post :bulk_archive, construct_params(params)
      assert_response 400
      match_json([bad_request_error_pattern('article', :invalid_field)])
    end
  end

  def test_archive_with_invalid_archive_days
    enable_archive_tickets do
      params = { archive_days: 'ten' }
      post :bulk_archive, construct_params(params)
      assert_response 400
      match_json([bad_request_error_pattern('archive_days', :datatype_mismatch, expected_data_type: Integer, prepend_msg: :input_received, given_data_type: String)])
    end
  end

  def test_archive_with_invalid_ticket_ids
    enable_archive_tickets do
      params = { archive_days: 0, ids: SAMPLE_TICKET_ID }
      post :bulk_archive, construct_params(params)
      assert_response 400
      match_json([bad_request_error_pattern('ids', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: Integer)])
    end
  end

  def test_archive_with_valid_parameters_archive_days_and_ticket_ids
    @account.make_current
    Account.stubs(:reset_current_account).returns(true)
    enable_archive_tickets do
      ticket = create_ticket
      ticket.update_attribute(:status , Helpdesk::Ticketfields::TicketStatus::CLOSED)
      sleep 1 #sleep introduced so that ticket.updated_at will be less that archive_days.days.ago
      params = { archive_days: 0, ids: [ticket.display_id] }
      freno_stub = stub_request(:get, 'http://freno.freshpo.com/check/ArchiveWorker/mysql/shard_1')
                   .to_return(status: 404, body: '', headers: {})
      central_stub = stub_request(:post, 'https://central-staging.freshworksapi.com/collector').to_return(status: 200, body: '', headers: {})
      ManualPublishWorker.stubs(:perform_async).returns('job_id')
      Sidekiq::Testing.inline! do
        post :bulk_archive, construct_params(params)
      end
      remove_request_stub(freno_stub)
      remove_request_stub(central_stub)
      assert_response 204
      assert @account.archive_tickets.find_by_ticket_id(ticket.id).present?
    end
    Account.unstub(:reset_current_account)
  end

  def test_archive_with_valid_parameter_ticket_ids
    @account.make_current
    Account.stubs(:reset_current_account).returns(true)
    enable_archive_tickets do
      ticket = create_ticket
      ticket.update_attribute(:status , Helpdesk::Ticketfields::TicketStatus::CLOSED)
      sleep 1 #sleep introduced so that ticket.updated_at will be less that archive_days.days.ago
      params = { ids: [ticket.display_id] }
      Sidekiq::Testing.inline! do
        post :bulk_archive, construct_params(params)
      end
      assert_response 204
    end
    Account.unstub(:reset_current_account)
  end

  def test_archive_with_valid_parameter_archive_days
    @account.make_current
    Account.stubs(:reset_current_account).returns(true)
    enable_archive_tickets do
      ticket = create_ticket
      ticket.update_attribute(:status , Helpdesk::Ticketfields::TicketStatus::CLOSED)
      sleep 1 #sleep introduced so that ticket.updated_at will be less that archive_days.days.ago
      params = { archive_days: 0 }
      freno_stub = stub_request(:get, 'http://freno.freshpo.com/check/ArchiveWorker/mysql/shard_1')
                   .to_return(status: 404, body: '', headers: {})
      central_stub = stub_request(:post, 'https://central-staging.freshworksapi.com/collector').to_return(status: 200, body: '', headers: {})
      ManualPublishWorker.stubs(:perform_async).returns('job_id')
      Sidekiq::Testing.inline! do
        post :bulk_archive, construct_params(params)
      end
      remove_request_stub(central_stub)
      remove_request_stub(freno_stub)
      assert_response 204
      assert @account.archive_tickets.find_by_ticket_id(ticket.id).present?
    end
    Account.unstub(:reset_current_account)
  end

  def test_archive_without_parameters
    @account.make_current
    enable_archive_tickets do
      params = {}
      Sidekiq::Testing.inline! do
        post :bulk_archive, construct_params(params)
      end  
      assert_response 204
    end
  end

  def test_archive_valid_ticket_ids_with_read_scope
    @account.make_current
    Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
    agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
    group1 = create_group_with_agents(@account, agent_list: [agent.id])
    group2 = create_group_with_agents(@account, agent_list: [agent.id])
    agent_group = agent.agent_groups.where(group_id: group1.id).first
    agent_group.write_access = false
    agent_group.save!
    ticket_ids = []
    Account.stubs(:reset_current_account).returns(true)
    enable_archive_tickets do
      ticket1 = create_ticket({ status: Helpdesk::Ticketfields::TicketStatus::CLOSED }, group1)
      ticket2 = create_ticket({ status: Helpdesk::Ticketfields::TicketStatus::CLOSED }, group2)
      sleep 1
      params = { ids: [ticket1.display_id, ticket2.display_id] }
      login_as(agent)
      Sidekiq::Testing.inline! do
        post :bulk_archive, construct_params(params)
      end
      assert_response 400
    end
  ensure
    group1.destroy if group1.present?
    group2.destroy if group2.present?
    Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    Account.unstub(:reset_current_account)
  end

  def test_bulk_delete_tickets_400_without_bulk_action_in_request_body
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)

    payload = { 'ids' => [10_000_000_001] }
    request_payload = {}
    dynamo_response = { 'payload' => payload, 'action' => 'bulk_delete' }
    Sidekiq::Testing.inline! do
      BulkApiJobs::Ticket.any_instance.stubs(:pick_job).returns(dynamo_response)
      post :bulk_delete, construct_params(request_payload)
    end
    assert_response 400
    pattern = { 'message' => 'Missing field', 'code' => 'missing_param' }
    match_json(pattern)
  ensure
    BulkApiJobs::Ticket.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end

  def test_bulk_delete_tickets_400_without_ids_in_request_body
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)

    payload = { 'ids' => [10_000_000_001] }
    request_payload = { 'bulk_action' => {} }
    dynamo_response = { 'payload' => payload, 'action' => 'bulk_delete' }
    Sidekiq::Testing.inline! do
      BulkApiJobs::Ticket.any_instance.stubs(:pick_job).returns(dynamo_response)
      post :bulk_delete, construct_params(request_payload)
    end
    assert_response 400
    pattern = { 'message' => 'Missing field', 'code' => 'missing_param' }
    match_json(pattern)
  ensure
    BulkApiJobs::Ticket.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end

  def test_bulk_delete_tickets_400_with_empty_tickets_id_array_in_request_body
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)

    payload = { 'ids' => [10_000_000_001] }
    request_payload = { 'bulk_action' => { 'ids' => [] } }
    dynamo_response = { 'payload' => payload, 'action' => 'bulk_delete' }
    Sidekiq::Testing.inline! do
      BulkApiJobs::Ticket.any_instance.stubs(:pick_job).returns(dynamo_response)
      post :bulk_delete, construct_params(request_payload)
    end
    assert_response 400
    pattern = { 'description' => 'Validation failed', 'errors' => [{ 'field' => 'ids', 'message' => 'It should not be blank as this is a mandatory field', 'code' => 'invalid_value' }] }
    match_json(pattern)
  ensure
    BulkApiJobs::Ticket.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end

  def test_bulk_delete_tickets_400_with_negative_tickets_id_array_in_request_body
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)

    payload = { 'ids' => [10_000_000_001] }
    request_payload = { 'bulk_action' => { 'ids' => [-1] } }
    dynamo_response = { 'payload' => payload, 'action' => 'bulk_delete' }
    Sidekiq::Testing.inline! do
      BulkApiJobs::Ticket.any_instance.stubs(:pick_job).returns(dynamo_response)
      post :bulk_delete, construct_params(request_payload)
    end
    assert_response 400
    pattern = { 'description' => 'Validation failed', 'errors' => [{ 'field' => 'ids', 'message' => 'It should contain elements of type Positive Integer only', 'code' => 'invalid_value' }] }
    match_json(pattern)
  ensure
    BulkApiJobs::Ticket.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end

  def test_bulk_delete_tickets_success
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)
    t = create_ticket(ticket_params_hash)
    tickets_array = [t.display_id]

    payload = { 'ids' => tickets_array }
    request_payload = { 'bulk_action' => payload }
    dynamo_response = { 'payload' => payload, 'action' => 'bulk_delete' }
    Sidekiq::Testing.inline! do
      BulkApiJobs::Ticket.any_instance.stubs(:pick_job).returns(dynamo_response)
      post :bulk_delete, construct_params(request_payload)
    end
    assert_response 202
    pattern = { job_id: uuid, href: @account.bulk_job_url(uuid) }
    match_json(pattern)
    assert_equal true, Account.current.tickets.find_by_display_id(t.display_id).deleted
  ensure
    BulkApiJobs::Ticket.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end

  def test_bulk_delete_tickets_partial_success
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)
    t = create_ticket(ticket_params_hash)
    tickets_array = [t.display_id, 10_000_000_001]

    payload = { 'ids' => tickets_array }
    request_payload = { 'bulk_action' => payload }
    dynamo_response = { 'payload' => payload, 'action' => 'bulk_delete' }
    Sidekiq::Testing.inline! do
      BulkApiJobs::Ticket.any_instance.stubs(:pick_job).returns(dynamo_response)
      post :bulk_delete, construct_params(request_payload)
    end
    assert_response 202
    pattern = { job_id: uuid, href: @account.bulk_job_url(uuid) }
    match_json(pattern)
    assert_equal true, Account.current.tickets.find_by_display_id(t.display_id).deleted
  ensure
    BulkApiJobs::Ticket.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end

  def test_bulk_delete_tickets_failure_no_permission
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)
    t = create_ticket(ticket_params_hash)
    tickets_array = [t.display_id, 10_000_000_001]
    payload = { 'ids' => tickets_array }
    request_payload = { 'bulk_action' => payload }
    dynamo_response = { 'payload' => payload, 'action' => 'bulk_delete' }

    Sidekiq::Testing.inline! do
      BulkApiJobs::Ticket.any_instance.stubs(:pick_job).returns(dynamo_response)
      Tickets::BulkTicketActions.any_instance.stubs(:check_ticket_delete_permission?).returns(false)

      post :bulk_delete, construct_params(request_payload)
    end
    assert_response 202
    pattern = { job_id: uuid, href: @account.bulk_job_url(uuid) }
    match_json(pattern)
    assert_equal false, Account.current.tickets.find_by_display_id(t.display_id).deleted
  ensure
    BulkApiJobs::Ticket.any_instance.unstub(:pick_job)
    Tickets::BulkTicketActions.any_instance.unstub(:check_ticket_delete_permission?)
    request.unstub(:uuid)
  end
end
