require_relative '../../test_helper'
require 'webmock/minitest'

class Tickets::BulkActionsControllerTest < ActionController::TestCase
  include ApiTicketsTestHelper
  include ArchiveTicketTestHelper

  SAMPLE_TICKET_ID = 31

  def setup
    super
    @account.enable_setting :archive_tickets_api
  end

  def rollback
    @account.disable_setting :archive_tickets_api
  end

  def test_archive_with_disable_archive_enabled
    # need to stub instead of destroy
    Account.any_instance.stubs(:disable_archive_enabled?).returns(true)
    params = {archive_days: 0, ids:[SAMPLE_TICKET_ID]}
    post :bulk_archive, construct_params(params)
    assert_response 403
    Account.any_instance.unstub(:disable_archive_enabled?)
  end

  def test_archive_without_archive_tickets_api
    @account.disable_setting :archive_tickets_api
    params = {archive_days: 0, ids:[SAMPLE_TICKET_ID]}
    post :bulk_archive, construct_params(params)
    assert_response 403
  end

  def test_archive_with_invalid_parameter
    enable_archive_tickets do
      params = {archive_days: 0, ids:[SAMPLE_TICKET_ID], article: 1}
      post :bulk_archive, construct_params(params)
      assert_response 400
      match_json([bad_request_error_pattern('article', :invalid_field)])
    end
  end

  def test_archive_with_invalid_archive_days
    enable_archive_tickets do
      params = {archive_days: 'ten'}
      post :bulk_archive, construct_params(params)
      assert_response 400
      match_json([bad_request_error_pattern('archive_days', :datatype_mismatch, expected_data_type: Integer, prepend_msg: :input_received, given_data_type: String)])
    end
  end

  def test_archive_with_invalid_ticket_ids
    enable_archive_tickets do
      params = {archive_days: 0, ids: SAMPLE_TICKET_ID}
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
      params = {archive_days: 0, ids:[ticket.display_id]}
      freno_stub = stub_request(:get, 'http://freno.freshpo.com/check/ArchiveWorker/mysql/shard_1')
                   .to_return(status: 404, body: '', headers: {})
      ManualPublishWorker.stubs(:perform_async).returns('job_id')
      Sidekiq::Testing.inline! do
        post :bulk_archive, construct_params(params)
      end
      remove_request_stub(freno_stub)
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
      params = {ids:[ticket.display_id]}
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
      params = {archive_days: 0}
      freno_stub = stub_request(:get, 'http://freno.freshpo.com/check/ArchiveWorker/mysql/shard_1')
                   .to_return(status: 404, body: '', headers: {})
      ManualPublishWorker.stubs(:perform_async).returns('job_id')
      Sidekiq::Testing.inline! do
        post :bulk_archive, construct_params(params)
      end
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
end
