require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'
require Rails.root.join('test', 'core', 'helpers', 'twitter_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class ChannelMessagePollerTest < ActionView::TestCase
  include AccountTestHelper
  include TwitterTestHelper

  def teardown
    cleanup_twitter_handles(@account)
  end

  def setup
    @user = create_test_account
    @account = @user.account
    Account.stubs(:current).returns(@account)
    @handle = create_test_twitter_handle(@account)
    @stream = @handle.default_stream
  end

  def test_twitter_dm_convert_as_ticket
    payload, command_payload = twitter_create_ticket_command
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

  # def test_update_social_tweets
  #   note = create_twitter_dm_ticket_and_note

  #   payload = { "status_code": 200, "tweet_id": '100000200', "note_id": note.id }
  #   command_payload = sample_twitter_dm_acknowledgement(@account, @handle, @stream, payload)
  #   push_to_channel(command_payload)

  #   tweet = @account.tweets.last
  #   assert_equal tweet[:tweetable_id], payload[:note_id]
  # end

  private

    def twitter_create_ticket_command
      payload = {
        "subject": Faker::Lorem.characters(50),
        "description": Faker::Lorem.characters(100),
        "requester_id": @account.users.last.id,
        "tweet_type": 'dm',
        "tweet_id": SecureRandom.hex
      }

      [payload, sample_twitter_create_ticket_command(@account, @handle, @stream, payload)]
    end

    def twitter_create_note_command
      tweet = @account.tweets.where(tweetable_type: 'Helpdesk::Ticket').last

      if tweet && tweet.tweetable_id
        ticket_id = @account.tickets.find(tweet.tweetable_id).display_id
      else
        payload, command_payload = twitter_create_ticket_command
        push_to_channel(command_payload)
        ticket_id = @account.tickets.last.display_id
      end

      # create a twitter contact and pass the ID to the user_id here.
      user = create_twitter_user
      payload = {
        "body": Faker::Lorem.characters(100),
        "user_id": user.id,
        "ticket_id": ticket_id,
        "tweet_type": 'dm',
        "tweet_id": SecureRandom.hex
      }

      [payload, sample_twitter_create_note_command(@account, @handle, @stream, payload)]
    end

    def create_twitter_dm_ticket
      payload, command_payload = twitter_create_ticket_command
      push_to_channel(command_payload)

      ticket = @account.tickets.last

      user = create_twitter_user
      ticket.notes.build({ body: Faker::Lorem.characters(100), user_id: user.id })
      ticket.save!

      ticket.notes.last.create_tweet({tweet_id: nil, tweet_type: 'dm', twitter_handle_id: @handle.id, stream_id: @stream.id})
      ticket.notes.save!

      ticket.notes.last
    end

    def push_to_channel(command_payload)
      sqs_msg = Hashit.new(body: { data: command_payload }.to_json)
      Ryuken::ChannelMessagePoller.new.perform(sqs_msg)
    end

    def create_twitter_user
      user = @account.users.build
      user.twitter_id = Faker::Lorem.characters(10)
      user.save
      user
    end
end
