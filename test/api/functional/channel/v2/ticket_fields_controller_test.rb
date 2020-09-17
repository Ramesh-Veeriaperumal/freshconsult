# frozen_string_literal: true

require_relative '../../../test_helper'
class Channel::V2::TicketFieldsControllerTest < ActionController::TestCase
  include CentralLib::CentralResyncHelper
  include CentralLib::CentralResyncConstants
  include Redis::OthersRedis

  SOURCE = 'analytics'
  SOURCE_WITHOUT_PERMISSION = 'silkroad'

  ERROR_RESPONSE = { description: 'Validation failed', errors: [{ 'field' => 'meta', 'message' => 'can\'t be blank', 'code' => 'invalid_value' }] }.freeze

  def wrap_cname(params)
    params
  end

  def test_sync_ticket_fields_auth_failure_403
    job_id = SecureRandom.hex
    request.stubs(:uuid).returns(job_id)
    remove_others_redis_key(resync_rate_limiter_key(SOURCE))
    remove_others_redis_key(format(CENTRAL_RESYNC_JOB_STATUS, source: SOURCE, job_id: job_id))
    post :sync, construct_params({ version: 'channel' }, meta: 'abc')
    assert_response 403
  end

  def test_sync_ticket_fields_source_without_permission
    job_id = SecureRandom.hex
    request.stubs(:uuid).returns(job_id)
    remove_others_redis_key(resync_rate_limiter_key(SOURCE_WITHOUT_PERMISSION))
    remove_others_redis_key(format(CENTRAL_RESYNC_JOB_STATUS, source: SOURCE_WITHOUT_PERMISSION, job_id: job_id))
    post :sync, construct_params({ version: 'channel' }, meta: 'abc')
    assert_response 403
  end

  def test_sync_ticket_fields_success_202_respone
    set_jwt_auth_header(SOURCE)
    job_id = SecureRandom.hex
    request.stubs(:uuid).returns(job_id)
    remove_others_redis_key(resync_rate_limiter_key(SOURCE))
    remove_others_redis_key(format(CENTRAL_RESYNC_JOB_STATUS, source: SOURCE, job_id: job_id))
    expected = { 'entity_name' => 'ticketfield', 'status' => RESYNC_JOB_STATUSES[:started], 'records_processed' => '0', 'last_model_id' => '' }.freeze
    expected_body = { 'job_id' => job_id }
    post :sync, construct_params({ version: 'channel' }, meta: { meta_id: 'abc' })
    response = parse_response @response.body
    assert_response 202
    assert_equal expected_body, response
    assert_equal expected, fetch_resync_job_information(SOURCE, job_id)
  end

  def test_sync_ticket_fields_validation_failure_400_respone_case_meta_info_missing
    set_jwt_auth_header(SOURCE)
    job_id = SecureRandom.hex
    request.stubs(:uuid).returns(job_id)
    remove_others_redis_key(resync_rate_limiter_key(SOURCE))
    remove_others_redis_key(format(CENTRAL_RESYNC_JOB_STATUS, source: SOURCE, job_id: job_id))
    post :sync, construct_params(version: 'channel')
    response = parse_response @response.body
    assert_response 400
    assert_equal ERROR_RESPONSE, response.symbolize_keys
  end

  def test_sync_ticket_fields_validation_failure_400_respone_case_meta_info_key_not_present
    set_jwt_auth_header(SOURCE)
    job_id = SecureRandom.hex
    request.stubs(:uuid).returns(job_id)
    remove_others_redis_key(resync_rate_limiter_key(SOURCE))
    remove_others_redis_key(format(CENTRAL_RESYNC_JOB_STATUS, source: SOURCE, job_id: job_id))
    post :sync, construct_params({ version: 'channel' }, meta_dup_key: 'abc')
    response = parse_response @response.body
    assert_response 400
    assert_equal ERROR_RESPONSE, response.symbolize_keys
  end

  def test_sync_ticket_fields_http_conflict_429
    set_jwt_auth_header(SOURCE)
    job_id = SecureRandom.hex
    request.stubs(:uuid).returns(job_id)
    set_others_redis_key_if_not_present(resync_rate_limiter_key(SOURCE), 5)
    remove_others_redis_key(format(CENTRAL_RESYNC_JOB_STATUS, source: SOURCE, job_id: job_id))
    post :sync, construct_params({ version: 'channel' }, meta: { meta_id: 'abc' })
    assert_response 429
  end
end
