# frozen_string_literal: true

require_relative '../test_helper'

class BulkApiJobsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    params
  end

  def setup
    super
  end

  def test_bulk_delete_tickets_success
    uuid = SecureRandom.hex
    dynamo_response = { 'request_id' => uuid, 'payload' => [{ 'id' => 1, 'success' => true }], 'status_id' => 2_000.0 }
    BulkApiJobsController.any_instance.stubs(:pick_job).returns(dynamo_response)
    get :show, controller_params(id: uuid)
    assert_response 200
    pattern = { 'id' => uuid, 'data' => [{ 'id' => 1, 'success' => true }], 'status' => 'SUCCESS' }
    match_json(pattern)
  ensure
    BulkApiJobsController.any_instance.unstub(:pick_job)
  end

  def test_bulk_delete_tickets_404_invalid_job_id
    uuid = SecureRandom.hex
    BulkApiJobsController.any_instance.stubs(:pick_job).returns(nil)
    get :show, controller_params(id: uuid)
    assert_response 404
  ensure
    BulkApiJobsController.any_instance.unstub(:pick_job)
  end

  def test_bulk_delete_tickets_success_intermediate_state
    uuid = SecureRandom.hex
    dynamo_response = { 'request_id' => uuid, 'payload' => [{ 'id' => 1, 'success' => true }], 'status_id' => 1_001.0 }
    BulkApiJobsController.any_instance.stubs(:pick_job).returns(dynamo_response)
    get :show, controller_params(id: uuid)
    assert_response 200
    pattern = { 'id' => uuid, 'status' => 'QUEUED' }
    match_json(pattern)
  ensure
    BulkApiJobsController.any_instance.unstub(:pick_job)
  end
end
