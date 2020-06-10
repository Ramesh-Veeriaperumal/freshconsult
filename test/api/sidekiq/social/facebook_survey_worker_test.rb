require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
Sidekiq::Testing.fake!

module Social
  class FacebookSurveyWorkerTest < ActionView::TestCase
    def setup
      Account.stubs(:current).returns(Account.first || create_test_account)
      Channel::CommandWorker.jobs.clear
    end

    def teardown
      Account.unstub(:current)
      super
    end

    def test_post_central_command
      old_count = Channel::CommandWorker.jobs.size
      Social::FacebookSurveyWorker.new.perform(construct_args)
      new_count = Channel::CommandWorker.jobs.size
      assert_equal old_count + 1, new_count
      command_args = Channel::CommandWorker.jobs.last['args'][0]
      assert_equal command_args['payload']['command_name'], Social::FB::Constants::SURVEY_DM_COMMAND_NAME
      assert_equal true, match_success_payload_context(command_args['payload'])
      assert_equal true, match_success_payload_data(command_args['payload'])
    end

    def construct_args
      {
        note_id: 1,
        user_id: 1,
        page_scope_id: 10,
        support_fb_page_id: 1000,
        survey_dm: 'Please fill the survey \n https://www.surveymonkey.com/r/MYMJL9H'
      }
    end

    def success_context
      {
        note_id: 1,
        user_id: 1
      }
    end

    def success_payload_data
      {
        page_scope_id: 10,
        support_fb_page_id: 1000,
        survey_dm: 'Please fill the survey \\n https://www.surveymonkey.com/r/MYMJL9H'
      }
    end

    def match_success_payload_context(payload)
      success_context == payload['context'].symbolize_keys!
    end

    def match_success_payload_data(payload)
      success_payload_data == payload['data'].symbolize_keys!
    end
  end
end
