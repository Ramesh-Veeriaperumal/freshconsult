require_relative '../unit_test_helper'
require_relative '../test_helper'
require_relative '../../test_transactions_fixtures_helper'
['twitter_test_helper', 'fb_test_helper', 'account_test_helper', 'shopify_test_helper'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

class ChannelMessagePollerTest < ActionView::TestCase
  include UsersTestHelper
  include AccountTestHelper
  include TwitterTestHelper
  include ShopifyTestHelper
  include FBTestHelper
  include SocialTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def teardown
    cleanup_twitter_handles(@account)
    Account.current.rollback(:skip_posting_to_fb)
  end

  def setup
    @user = create_test_account
    @account = @user.account
    Account.stubs(:current).returns(@account)
    @handle = create_test_twitter_handle(@account)
    @stream = @handle.default_stream
    @fb_ticket = create_ticket_from_fb_post
    @fb_page = @fb_ticket.fb_post.facebook_page
    Account.current.launch(:skip_posting_to_fb)
  end

  def test_twitter_dm_convert_as_ticket
    payload, command_payload = twitter_create_ticket_command('dm')
    push_to_channel(command_payload)

    ticket = @account.tickets.last
    tweet = @account.tweets.last

    assert_equal tweet[:tweetable_id], ticket.id
    assert_equal ticket.description, payload[:description]
    assert_equal tweet.tweet_type, 'dm'
  end

  def test_twitter_mention_convert_as_ticket_and_conflict_case
    payload, command_payload = twitter_create_ticket_command('mention')
    push_to_channel(command_payload)

    ticket = @account.tickets.last
    tweet = @account.tweets.last

    assert_equal tweet[:tweetable_id], ticket.id
    assert_equal ticket.description, payload[:description]
    assert_equal tweet.tweet_type, 'mention'

    conflict_result = ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    assert_equal conflict_result, conflict_reply_payload(ticket, payload[:tweet_id])
  end

  def test_twitter_mention_convert_as_note_and_conflict_case
    Account.current.launch(:outgoing_tweets_to_tms)
    payload, command_payload = twitter_create_note_command('mention')
    push_to_channel(command_payload)

    ticket = @account.tickets.find_by_display_id(payload[:ticket_id])
    note = ticket.notes.find_by_notable_id(ticket.id)
    tweet = @account.tweets.last

    assert_equal tweet[:tweetable_id], note.id
    assert_equal note.body, payload[:body]
    assert_equal tweet.tweet_type, 'mention'

    conflict_result = ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    assert_equal conflict_result, conflict_reply_payload(note, payload[:tweet_id])
  ensure
    Account.current.rollback(:outgoing_tweets_to_tms)
  end

  def test_twitter_mention_convert_as_ticket
    payload, command_payload = twitter_create_ticket_command('mention')
    push_to_channel(command_payload)

    ticket = @account.tickets.last
    tweet = @account.tweets.last

    assert_equal tweet[:tweetable_id], ticket.id
    assert_equal ticket.description, payload[:description]
  end

  # def test_twitter_dm_convert_as_note
  #   payload, command_payload = twitter_create_note_command
  #   push_to_channel(command_payload)

  #   ticket = @account.tickets.find_by_display_id(payload[:ticket_id])
  #   note = ticket.notes.last
  #   tweet = @account.tweets.last

  #   assert_equal tweet[:tweetable_id], note.id
  #   assert_equal note.body, payload[:body]
  # end

  def test_update_social_tweets_for_dm
    note = create_twitter_ticket_and_note
    fake_tweet_id = Faker::Number.between(1, 999999999).to_s
    payload = { "status_code": 200, "tweet_id": fake_tweet_id, "note_id": note.id }
    command_payload = sample_twitter_reply_acknowledgement(@account, @handle, @stream, payload)
    push_to_channel(command_payload)

    tweet = @account.tweets.last
    assert_equal tweet[:tweetable_id], payload[:note_id]
    assert_equal tweet[:tweet_id].to_s, payload[:tweet_id]
  end

  def test_update_social_tweets_for_mention
    Account.current.launch(:outgoing_tweets_to_tms)
    note = create_twitter_ticket_and_note('mention')
    fake_tweet_id = Faker::Number.between(1, 999999999).to_s
    payload = { 'status_code': 200, 'tweet_id': fake_tweet_id, 'note_id': note.id, 'tweet_type': 'mention' }
    command_payload = sample_twitter_reply_acknowledgement(@account, @handle, @stream, payload)
    push_to_channel(command_payload)

    tweet = @account.tweets.last
    assert_equal tweet[:tweetable_id], payload[:note_id]
    assert_equal tweet[:tweet_id].to_s, payload[:tweet_id]
  ensure
    Account.current.rollback(:outgoing_tweets_to_tms)
  end

  def test_update_social_tweets_with_error
    remove_others_redis_key TWITTER_APP_BLOCKED
    payload = { "status_code": 403, "tweet_id": '100000200', "note_id": 123, "code": Twitter::Error::Codes::CANNOT_WRITE }
    command_payload = sample_twitter_reply_acknowledgement(@account, @handle, @stream, payload)
    push_to_channel(command_payload)

    assert_equal true, redis_key_exists?(TWITTER_APP_BLOCKED)
  ensure
    remove_others_redis_key TWITTER_APP_BLOCKED
  end

  def test_shopify_convert_as_ticket
    payload, command_payload = proactive_create_ticket_command
    push_to_channel(command_payload)
    ticket = @account.tickets.last
    assert_equal ticket.description, payload[:description]
    assert_equal ticket.subject, payload[:subject]
    assert_equal ticket.status, 5
  end

  def test_shopify_placeholders_convert_as_ticket
    description = description_with_shopify_placeholders
    payload, command_payload = proactive_create_ticket_command(description)
    push_to_channel(command_payload)
    ticket = @account.tickets.last
    assert_equal ticket.status, 5
    assert_equal ticket.subject, payload[:subject]
  end

  def test_unblock_app_command_payload
    sqs_body = {
      data: {
        payload_type: 'helpkit_command',
        account_id: @account.id,
        owner: 'twitter',
        command: 'unblock_app',
        payload: {
          data: {},
          context: {},
          command_name: 'unblock_app',
          owner: 'twitter',
          pod: 'development'
        },
        msg_id: Faker::Lorem.characters(50)

      }
    }
    sqs_payload = Minitest::Mock.new
    sqs_payload.expect(:body, sqs_body.to_json)
    $redis_others.perform_redis_op('set', 'TWITTER_APP_BLOCKED', true)
    Ryuken::ChannelMessagePoller.new.perform(sqs_payload)
    redis_key_status = $redis_others.perform_redis_op('exists', 'TWITTER_APP_BLOCKED')
    assert redis_key_status.blank?
  end

  # Facebook command tests
  def test_update_facebook_reply_state_success
    note = create_post_note_with_negative_post_id(@fb_ticket)
    old_post_id = note.fb_post.post_id

    command_payload = update_facebook_reply_state_command_payload(@account, note, @fb_page)
    push_to_channel(command_payload)

    new_post_id = @fb_ticket.notes.last.fb_post.post_id
    assert_not_equal old_post_id, new_post_id
  end

  def test_update_facebook_reply_state_failure
    note = create_post_note_with_negative_post_id(@fb_ticket)
    old_post_id = note.fb_post.post_id

    command_payload = update_facebook_reply_state_command_payload(@account, note, @fb_page)
    command_payload[:payload][:data] = update_facebook_reply_state_failure_data_payload
    push_to_channel(command_payload)

    new_post_id = @fb_ticket.notes.last.fb_post.post_id
    assert_equal old_post_id, new_post_id
  end

  private

    def twitter_create_ticket_command(tweet_type)
      payload = {
        "subject": Faker::Lorem.characters(50),
        "description": Faker::Lorem.characters(100),
        "requester_id": @account.users.last.id,
        "tweet_type": tweet_type,
        "tweet_id": SecureRandom.hex
      }

      [payload, sample_twitter_create_ticket_command(@account, @handle, @stream, payload)]
    end

    def twitter_create_note_command(tweet_type = 'dm')
      tweet = @account.tweets.where(tweetable_type: 'Helpdesk::Ticket').last

      if tweet && tweet.tweetable_id
        ticket_id = @account.tickets.find(tweet.tweetable_id).display_id
      else
        payload, command_payload = twitter_create_ticket_command(tweet_type)
        push_to_channel(command_payload)
        ticket_id = @account.tickets.last.display_id
      end

      # create a twitter contact and pass the ID to the user_id here.
      user = create_twitter_user
      payload = {
        "body": Faker::Lorem.characters(100),
        "user_id": user.id,
        "ticket_id": ticket_id,
        "tweet_type": tweet_type,
        "tweet_id": SecureRandom.hex
      }

      [payload, sample_twitter_create_note_command(@account, @handle, @stream, payload)]
    end

    def create_twitter_ticket_and_note(tweet_type = 'dm')
      payload, command_payload = twitter_create_ticket_command(tweet_type)
      push_to_channel(command_payload)

      ticket = @account.tickets.last

      user = create_twitter_user
      ticket.notes.build({ body: Faker::Lorem.characters(100), user_id: user.id })
      ticket.save!

      last_note = ticket.notes.last

      last_note.build_tweet(tweet_id: random_tweet_id, tweet_type: tweet_type, twitter_handle_id: @handle.id, stream_id: @stream.id)
      last_note.save!

      last_note
    end

    def proactive_create_ticket_command(description=nil)
      payload = {
        "subject": Faker::Lorem.characters(50),
        "description": description || Faker::Lorem.characters(100),
        "requester_id": @account.users.last.id,
      }

      [payload, sample_shopify_create_ticket_command(@account, 'proactive_delivery_feedback', payload)]
    end

    def description_with_shopify_placeholders
      "<div>Total price :&nbsp;</div><div>{{shopify.total_price}}</div><div><br></div><div>First name :&nbsp;</div><div>{{shopify.customer.first_name}}</div>"
    end

    def push_to_channel(command_payload)
      sqs_msg = Hashit.new(body: { data: command_payload }.to_json)
      Ryuken::ChannelMessagePoller.new.perform(sqs_msg)
    end

    def create_twitter_user
      user = add_new_user(@account)
      user.twitter_id = Faker::Lorem.characters(10)
      user.save
      user
    end

    def random_tweet_id
      -"#{Time.now.utc.to_i}#{rand(100...999)}".to_i
    end
end
