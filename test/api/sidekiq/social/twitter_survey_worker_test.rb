require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
Sidekiq::Testing.fake!

module Social
  class TwitterSurveyWorkerTest < ActionView::TestCase
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
      Social::TwitterSurveyWorker.new.perform(construct_args)
      new_count = Channel::CommandWorker.jobs.size
      assert_equal old_count + 1, new_count
      command_args = Channel::CommandWorker.jobs.last['args'][0]
      assert_equal command_args['payload']['command_name'], Social::Twitter::Constants::SURVEY_DM_COMMAND_NAME
      assert_equal true, match_success_payload_context(command_args['payload'])
      assert_equal true, match_success_payload_data(command_args['payload'])
    end

    def construct_args
      {
        note_id: 1,
        user_id: 1,
        requester_screen_name: 'test',
        twitter_user_id: 1234,
        twitter_handle_id: 4444,
        stream_id: 123,
        tweet_type: 'dm',
        survey_dm: 'Please fill the survey \n https://www.surveymonkey.com/r/MYMJL9H'
      }
    end

    def success_context
      {
        'tweet_type': 'dm',
        'stream_id': 123,
        'note_id': 1,
        'twitter_handle_id': 4444
      }
    end

    def success_data
      {
        user_id: 1,
        requester_screen_name: 'test',
        twitter_user_id: 1234,
        survey_dm: 'Please fill the survey \n https://www.surveymonkey.com/r/MYMJL9H'
      }
    end

    def match_success_payload_context(payload)
      success_context == payload['context'].symbolize_keys!
    end

    def match_success_payload_data(payload)
      success_data == payload['data'].symbolize_keys!
    end
  end
end
