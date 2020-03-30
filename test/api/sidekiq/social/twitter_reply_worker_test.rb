require_relative '../../unit_test_helper'
require_relative '../../../../spec/support/social_tickets_creation_helper'
require_relative '../../../../spec/support/note_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

module Social
  class TwitterReplyWorkerTest < ActionView::TestCase
    include AccountTestHelper
    include SocialTicketsCreationHelper
    include NoteHelper

    def setup
      Account.stubs(:current).returns(Account.first || create_test_account)
      TwitterReplyWorker.any_instance.stubs(:update_errors_in_schema_less_notes).returns(true)
      TwitterReplyWorker.any_instance.stubs(:notify_iris).returns(true)
      @account = Account.current
      @twitter_ticket = create_twitter_ticket
      @twitter_note = sample_twitter_note(@twitter_ticket)
      Channel::CommandWorker.jobs.clear
    end

    def teardown
      Account.unstub(:current)
      super
    end

    def test_publish_error_to_central
      old_count = Channel::CommandWorker.jobs.size
      TwitterReplyWorker.any_instance.stubs(:send_tweet_as_mention).returns(['error in twitter', nil, '500'])
      Social::TwitterReplyWorker.new.perform(construct_args)
    rescue StandardError => e
      new_count = Channel::CommandWorker.jobs.size
      assert_equal old_count + 1, new_count
      assert_equal true,
                   match_error_response_payload(Channel::CommandWorker.jobs.last['args'][0]['payload'])
    end

    def test_publish_success_to_central
      old_count = Channel::CommandWorker.jobs.size
      TwitterReplyWorker.any_instance.stubs(:send_tweet_as_mention).returns([nil, 4321, nil])
      Social::TwitterReplyWorker.new.perform(construct_args)
      new_count = Channel::CommandWorker.jobs.size
      assert_equal old_count + 1, new_count
      assert_equal true,
                   match_success_response_payload(Channel::CommandWorker.jobs.last['args'][0]['payload'])
    end

    def test_publish_success_to_central_with_emoji
      old_count = Channel::CommandWorker.jobs.size
      twitter_note = sample_twitter_note_with_emoji(@twitter_ticket)
      TwitterReplyWorker.any_instance.stubs(:send_tweet_as_mention).returns([nil, 4321, nil])
      Social::TwitterReplyWorker.new.perform(construct_args)
      new_count = Channel::CommandWorker.jobs.size
      assert_equal old_count + 1, new_count
      assert_equal true,
                   match_success_response_payload(Channel::CommandWorker.jobs.last['args'][0]['payload'])
    end

    def construct_args
      {
        ticket_id: @twitter_ticket.id,
        note_id: @twitter_note.id,
        tweet_type: 'mention',
        twitter_handle_id: '1234'
      }
    end

    def sample_twitter_note(ticket)
      note = create_note(source: 5, ticket_id: ticket.id, user_id: ticket.requester.id, private: false, body: Faker::Lorem.paragraph)
      note.build_tweet(tweet_id: 1234, tweet_type: 'mention', twitter_handle_id: get_twitter_handle.id)
      note.save
      note.reload
    end

    def sample_twitter_note_with_emoji(ticket)
      note = create_note(source: 5, ticket_id: ticket.id, user_id: ticket.requester.id, private: false, body: "hey 👋 there⛺️😅💁")
      note.build_tweet(tweet_id: 1234, tweet_type: 'mention', twitter_handle_id: get_twitter_handle.id)
      note.save
      note.reload
    end

    def error_payload
      {
        status_code: '500',
        message: 'error in twitter',
        code: '500',
        tweet_type: 'mention',
        stream_id: nil,
        note_id: @twitter_note.id,
        twitter_handle_id: '1234'
      }
    end

    def success_payload
      {
        status_code: 200,
        tweet_id: 4321,
        tweet_type: 'mention',
        stream_id: nil,
        note_id: @twitter_note.id,
        twitter_handle_id: '1234'
      }
    end

    def match_error_response_payload(sidekiq_job)
      error_payload == {
        status_code: sidekiq_job['data']['status_code'],
        message: sidekiq_job['data']['message'],
        code: sidekiq_job['data']['code'],
        tweet_type: sidekiq_job['context']['tweet_type'],
        stream_id: sidekiq_job['context']['stream_id'],
        note_id: sidekiq_job['context']['note_id'],
        twitter_handle_id: sidekiq_job['context']['twitter_handle_id']
      }
    end

    def match_success_response_payload(sidekiq_job)
      success_payload == {
        status_code: sidekiq_job['data']['status_code'],
        tweet_id: sidekiq_job['data']['tweet_id'],
        tweet_type: sidekiq_job['context']['tweet_type'],
        stream_id: sidekiq_job['context']['stream_id'],
        note_id: sidekiq_job['context']['note_id'],
        twitter_handle_id: sidekiq_job['context']['twitter_handle_id']
      }
    end
  end
end
