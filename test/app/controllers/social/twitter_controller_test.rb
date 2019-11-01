require_relative '../../../api/test_helper'
require_relative '../../../core/helpers/users_test_helper'
['account_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['twitter_helper.rb', 'social_tickets_creation_helper.rb', 'dynamo_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class Social::TwitterControllerTest < ActionController::TestCase
  
  include TwitterHelper
  include Social::Twitter::Constants
  include AccountTestHelper
  include SocialTestHelper
  include SocialTicketsCreationHelper
  include CoreUsersTestHelper
  include DynamoHelper

  def setup
    super
    account = current_account
    @twitter_handle = get_twitter_handle
    @default_stream = @twitter_handle.default_stream
  end

  def current_account
    Account.first || create_test_account
  end

  def test_twitter_reply_to_tweet_ticket_from_social_tab
    user = Account.current.account_managers.first.make_current
    @controller.stubs(:current_user).returns(user)
    Account.current.stubs(:outgoing_tweets_to_tms_enabled?).returns(false)
    @request.env['HTTP_ACCEPT'] = 'application/json'
    with_twitter_update_stubbed do
      ticket = create_twitter_ticket
      @account = Account.current
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130],
          in_reply_to: ticket.tweet.tweet_id
        },
        twitter_handle_id: @twitter_handle.id,
        search_type: 'streams'
      }
      User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(true)
      post :reply, params_hash, format: 'js'
      assert_response 200
      latest_note = ticket.notes.last
      tweet = latest_note.tweet
      assert_equal tweet.tweet_id, @twit.id
      assert_equal tweet.stream_id, @default_stream.id
      ticket.destroy
    end
  ensure
    Account.current.unstub(:outgoing_tweets_to_tms_enabled?)
    User.any_instance.unstub(:privilege?)
    @controller.unstub(:current_user)
  end

  def test_twitter_reply_to_tweet_ticket_from_social_tab_with_feature_enabled
    user = Account.current.account_managers.first.make_current
    @controller.stubs(:current_user).returns(user)
    Account.current.launch(:outgoing_tweets_to_tms) 
    @request.env['HTTP_ACCEPT'] = 'application/json'
    with_twitter_update_stubbed do
      ticket = create_twitter_ticket
      @account = Account.current
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130],
          in_reply_to: ticket.tweet.tweet_id
        },
        twitter_handle_id: @twitter_handle.id,
        search_type: 'streams'
      }
      User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(true)
      post :reply, params_hash, format: 'js'
      assert_response 200
      latest_note = ticket.notes.last
      tweet = latest_note.tweet
      assert_equal tweet.tweet_id < 0, true, 'Tweet id should be less than zero'
      assert_equal tweet.stream_id, @default_stream.id
      ticket.destroy
    end
  ensure
    Account.current.rollback(:outgoing_tweets_to_tms)
    User.any_instance.unstub(:privilege?)
    @controller.unstub(:current_user)
  end
end
