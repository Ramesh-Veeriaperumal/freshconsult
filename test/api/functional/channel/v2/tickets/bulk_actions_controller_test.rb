require_relative '../../../../test_helper'
require 'webmock/minitest'

class Channel::V2::Tickets::BulkActionsControllerTest < ActionController::TestCase
  include ApiTicketsTestHelper
  include ArchiveTicketTestHelper

  SAMPLE_TICKET_ID = 31

  def wrap_cname(params)
    { bulk_action: params }
  end

  def setup
    super
    @account.launch :archive_tickets_api
  end

  def rollback
    @account.rollback :archive_tickets_api
  end

  def test_archive_with_disable_archive_enabled
    # need to stub instead of destroy
    Account.any_instance.stubs(:all_launched_features).returns([:disable_archive])
    params = { archive_days: 0, ids: [SAMPLE_TICKET_ID] }
    post :bulk_archive, construct_params({}, params)
    assert_response 403
    Account.any_instance.unstub(:all_launched_features)
  end

  def test_archive_without_archive_tickets_api
    @account.rollback :archive_tickets_api
    params = { archive_days: 0, ids: [SAMPLE_TICKET_ID] }
    post :bulk_archive, construct_params({}, params)
    assert_response 403
  end

  def test_archive_with_invalid_parameter
    enable_archive_tickets do
      params = { archive_days: 0, ids: [SAMPLE_TICKET_ID], article: 1 }
      post :bulk_archive, construct_params({}, params)
      assert_response 400
      match_json([bad_request_error_pattern('article', :invalid_field)])
    end
  end

  def test_archive_with_invalid_archive_days
    enable_archive_tickets do
      params = { archive_days: 'ten' }
      post :bulk_archive, construct_params({}, params)
      assert_response 400
      match_json([bad_request_error_pattern('archive_days', :datatype_mismatch, expected_data_type: Integer, prepend_msg: :input_received, given_data_type: String)])
    end
  end

  def test_archive_with_invalid_ticket_ids
    enable_archive_tickets do
      params = { archive_days: 0, ids: SAMPLE_TICKET_ID }
      post :bulk_archive, construct_params({}, params)
      assert_response 400
      match_json([bad_request_error_pattern('ids', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: Integer)])
    end
  end

  def test_archive_with_valid_parameters_archive_days_and_ticket_ids
    @account.make_current
    Account.stubs(:reset_current_account).returns(true)
    enable_archive_tickets do
      ticket = create_ticket
      ticket.update_attribute(:status, Helpdesk::Ticketfields::TicketStatus::CLOSED)
      sleep 1 # sleep introduced so that ticket.updated_at will be less that archive_days.days.ago
      params = { archive_days: 0, ids: [ticket.display_id] }
      freno_stub = stub_request(:get, 'http://freno.freshpo.com/check/ArchiveWorker/mysql/shard_1')
                   .to_return(status: 404, body: '', headers: {})
      central_stub = stub_request(:post, 'https://central-staging.freshworksapi.com/collector').to_return(body: '', status: 202)
      ManualPublishWorker.stubs(:perform_async).returns('job_id')
      Sidekiq::Testing.inline! do
        post :bulk_archive, construct_params({}, params)
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
      ticket.update_attribute(:status, Helpdesk::Ticketfields::TicketStatus::CLOSED)
      sleep 1 # sleep introduced so that ticket.updated_at will be less that archive_days.days.ago
      params = { ids: [ticket.display_id] }
      Sidekiq::Testing.inline! do
        post :bulk_archive, construct_params({}, params)
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
      ticket.update_attribute(:status, Helpdesk::Ticketfields::TicketStatus::CLOSED)
      sleep 1 # sleep introduced so that ticket.updated_at will be less that archive_days.days.ago
      params = { archive_days: 0 }
      freno_stub = stub_request(:get, 'http://freno.freshpo.com/check/ArchiveWorker/mysql/shard_1')
                   .to_return(status: 404, body: '', headers: {})
      central_stub = stub_request(:post, 'https://central-staging.freshworksapi.com/collector').to_return(body: '', status: 202)
      ManualPublishWorker.stubs(:perform_async).returns('job_id')
      Sidekiq::Testing.inline! do
        post :bulk_archive, construct_params({}, params)
      end
      remove_request_stub(freno_stub)
      remove_request_stub(central_stub)
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
        post :bulk_archive, construct_params({}, params)
      end
      assert_response 204
    end
  end
end
