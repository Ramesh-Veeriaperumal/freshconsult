# frozen_string_literal: true

require_relative '../../../test_helper'
module Channel::V2
  class CentralResyncControllerTest < ActionController::TestCase
    include CentralLib::CentralResyncHelper
    include JwtTestHelper

    SOURCE = 'field_service'.freeze # Temporary source for test

    def wrap_cname(params)
      { central_resync: params }
    end

    def test_show_with_invalid_jobid
      set_jwt_auth_header(SOURCE)
      get :show, construct_params(version: 'channel', id: rand(1_000_000))
      assert_response 404
    end

    def test_show_with_valid_jobid
      set_jwt_auth_header(SOURCE)
      job_id = rand(1_000_000)
      entity_name = Faker::Lorem.word
      push_resync_job_information(SOURCE, job_id, entity_name)
      get :show, construct_params(version: 'channel', id: job_id)
      assert_response 200
      match_json(resync_success_response(entity_name))
    end

    private

      def resync_success_response(entity_name, status = RESYNC_JOB_STATUSES[:started], records_processed = '0', last_model_id = '')
        {
          "entity_name": entity_name,
          "status": status,
          "records_processed": records_processed,
          "last_model_id": last_model_id
        }
      end
  end
end
