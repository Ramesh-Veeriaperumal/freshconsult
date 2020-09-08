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
  include ArchiveTicketTestHelper

  ARCHIVE_DAYS = 120
  TICKET_UPDATED_DATE = 150.days.ago

  def teardown
    cleanup_twitter_handles(@account)
  end

  def setup
    @user = create_test_account
    @account = @user.account
    Account.stubs(:current).returns(@account)
    @handle = create_test_twitter_handle(@account)
    @stream = @handle.default_stream
    @fb_ticket = create_ticket_from_fb_post
    @fb_page = @fb_ticket.fb_post.facebook_page
  end

  def test_twitter_dm_convert_as_ticket
    payload, command_payload = twitter_create_ticket_command('dm')
    push_to_channel(command_payload)

    ticket = @account.tickets.where(subject: payload[:subject]).first
    tweet = ticket.tweet

    assert_not_nil tweet
    assert_equal tweet[:tweetable_id], ticket.id
    assert_equal ticket.description, payload[:description]
    assert_equal tweet.tweet_type, 'dm'
  end

  def test_twitter_mention_convert_as_ticket_and_conflict_case
    payload, command_payload = twitter_create_ticket_command('mention')
    push_to_channel(command_payload)

    ticket = @account.tickets.where(subject: payload[:subject]).first
    tweet = ticket.tweet

    assert_not_nil tweet
    assert_equal tweet[:tweetable_id], ticket.id
    assert_equal ticket.description, payload[:description]
    assert_equal tweet.tweet_type, 'mention'

    conflict_result = ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    assert_equal conflict_result, conflict_reply_payload(ticket.display_id, payload[:tweet_id])
  end

  def test_twitter_mention_convert_as_note_and_ticket_archived_case
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    payload, command_payload = twitter_create_note_command('mention',true)
    archive_result = ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    assert_equal archive_result, ticket_archived_error_payload(payload[:ticket_id])
  end

  def test_twitter_mention_convert_as_ticket
    payload, command_payload = twitter_create_ticket_command('mention')
    push_to_channel(command_payload)

    ticket = @account.tickets.where(subject: payload[:subject]).first
    tweet = ticket.tweet

    assert_not_nil tweet
    assert_equal tweet[:tweetable_id], ticket.id
    assert_equal ticket.description, payload[:description]
  end

  def test_twitter_mention_convert_as_ticket_and_update_twitter_contact_fields
    payload, command_payload = twitter_create_ticket_command('mention')
    data = command_payload[:payload][:data]
    twitter_profile_status = data[:twitter_profile_status]
    twitter_followers_count = data[:twitter_followers_count]
    push_to_channel(command_payload)
    user = @account.users.find(data[:requester_id])
    assert_equal twitter_profile_status, user.twitter_profile_status
    assert_equal twitter_followers_count, user.twitter_followers_count
  end

  def test_twitter_mention_convert_as_ticket_and_update_twitter_contact_fields_without_values_in_payload
    payload, command_payload = twitter_create_ticket_command('mention')
    data = command_payload[:payload][:data]
    data.delete(:twitter_profile_status)
    data.delete(:twitter_followers_count)
    push_to_channel(command_payload)
    user = @account.users.find(data[:requester_id])
    assert_equal false, user.twitter_profile_status
    assert_nil user.twitter_followers_count
  end

  def test_twitter_mention_convert_as_note_and_update_twitter_contact_fields
    payload, command_payload = twitter_create_note_command('mention', true)
    data = command_payload[:payload][:data]
    twitter_profile_status = data[:twitter_profile_status]
    twitter_followers_count = data[:twitter_followers_count]
    ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    user = @account.users.find(data[:user_id])
    assert_equal twitter_profile_status, user.twitter_profile_status
    assert_equal twitter_followers_count, user.twitter_followers_count
  ensure
    Account.reset_current_account
  end

  def test_update_twitter_contact_fields_without_values_in_payload
    payload, command_payload = twitter_create_note_command('mention', true)
    data = command_payload[:payload][:data]
    data.delete(:twitter_profile_status)
    data.delete(:twitter_followers_count)
    ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    user = Account.current.users.find(data[:user_id])
    assert_equal false, user.twitter_profile_status
    assert_nil user.twitter_followers_count
  ensure
    Account.reset_current_account
  end

  def test_twitter_mention_convert_as_ticket_and_populate_requester_handle_id
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    payload, command_payload = twitter_create_ticket_command('mention')
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    twitter_requester_handle_id = context[:contact_twitter_user_id]
    push_to_channel(command_payload)
    user = @account.users.find(data[:requester_id])
    assert_equal twitter_requester_handle_id, user.twitter_requester_handle_id
  ensure
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_twitter_mention_convert_as_ticket_and_not_populate_requester_handle_id_without_values_in_payload
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    payload, command_payload = twitter_create_ticket_command('mention')
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    context.delete(:contact_twitter_user_id)
    push_to_channel(command_payload)
    user = @account.users.find(data[:requester_id])
    assert_nil user.twitter_requester_handle_id
  ensure
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_twitter_mention_convert_as_ticket_and_not_populate_requester_handle_id_without_feature
    payload, command_payload = twitter_create_ticket_command('mention')
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    twitter_requester_handle_id = context[:contact_twitter_user_id]
    push_to_channel(command_payload)
    user = @account.users.find(data[:requester_id])
    assert_nil user.twitter_requester_handle_id
  end

  def test_twitter_dm_convert_as_ticket_and_populate_requester_handle_id
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    payload, command_payload = twitter_create_ticket_command('dm')
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    twitter_requester_handle_id = context[:contact_twitter_user_id]
    push_to_channel(command_payload)
    user = @account.users.find(data[:requester_id])
    assert_equal twitter_requester_handle_id, user.twitter_requester_handle_id
  ensure
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_twitter_dm_convert_as_ticket_and_not_populate_requester_handle_id_without_values_in_payload
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    payload, command_payload = twitter_create_ticket_command('dm')
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    context.delete(:contact_twitter_user_id)
    push_to_channel(command_payload)
    user = @account.users.find(data[:requester_id])
    assert_nil user.twitter_requester_handle_id
  ensure
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_twitter_dm_convert_as_ticket_and_not_populate_requester_handle_id_without_feature
    payload, command_payload = twitter_create_ticket_command('dm')
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    twitter_requester_handle_id = context[:contact_twitter_user_id]
    push_to_channel(command_payload)
    user = @account.users.find(data[:requester_id])
    assert_nil user.twitter_requester_handle_id
  end

  def test_twitter_mention_convert_as_note_and_populate_requester_handle_id
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    Account.current.launch(:incoming_mentions_in_tms)
    payload, command_payload = twitter_create_note_command('mention')
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    twitter_requester_handle_id = context[:contact_twitter_user_id]
    ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    user = @account.users.find(data[:user_id])
    assert_equal twitter_requester_handle_id, user.twitter_requester_handle_id
  ensure
    Account.current.rollback(:incoming_mentions_in_tms)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
    Account.reset_current_account
  end

  def test_twitter_mention_convert_as_note_and_not_populate_requester_handle_id_without_values_in_payload
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    Account.current.launch(:incoming_mentions_in_tms)
    payload, command_payload = twitter_create_note_command('mention')
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    context.delete(:contact_twitter_user_id)
    ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    user = @account.users.find(data[:user_id])
    assert_nil user.twitter_requester_handle_id
  ensure
    Account.current.rollback(:incoming_mentions_in_tms)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
    Account.reset_current_account
  end

  def test_twitter_mention_convert_as_note_and_not_populate_requester_handle_id_without_feature
    Account.current.launch(:incoming_mentions_in_tms)
    payload, command_payload = twitter_create_note_command('mention')
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    twitter_requester_handle_id = context[:contact_twitter_user_id]
    ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    user = @account.users.find(data[:user_id])
    assert_nil user.twitter_requester_handle_id
  ensure
    Account.current.rollback(:incoming_mentions_in_tms)
    Account.reset_current_account
  end

  def test_twitter_dm_convert_as_note_and_populate_requester_handle_id
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    Account.current.launch(:incoming_mentions_in_tms)
    payload, command_payload = twitter_create_note_command
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    twitter_requester_handle_id = context[:contact_twitter_user_id]
    ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    user = @account.users.find(data[:user_id])
    assert_equal twitter_requester_handle_id, user.twitter_requester_handle_id
  ensure
    Account.current.rollback(:incoming_mentions_in_tms)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
    Account.reset_current_account
  end

  def test_twitter_dm_convert_as_note_and_not_populate_requester_handle_id_without_values_in_payload
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    Account.current.launch(:incoming_mentions_in_tms)
    payload, command_payload = twitter_create_note_command
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    context.delete(:contact_twitter_user_id)
    ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    user = @account.users.find(data[:user_id])
    assert_nil user.twitter_requester_handle_id
  ensure
    Account.current.rollback(:incoming_mentions_in_tms)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
    Account.reset_current_account
  end

  def test_twitter_dm_convert_as_note_and_not_populate_requester_handle_id_without_feature
    Account.current.launch(:incoming_mentions_in_tms)
    payload, command_payload = twitter_create_note_command
    data = command_payload[:payload][:data]
    context = command_payload[:payload][:context]
    twitter_requester_handle_id = context[:contact_twitter_user_id]
    ChannelIntegrations::Commands::Processor.new.process(command_payload[:payload])
    user = @account.users.find(data[:user_id])
    assert_nil user.twitter_requester_handle_id
  ensure
    Account.current.rollback(:incoming_mentions_in_tms)
    Account.reset_current_account
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
    fake_tweet_id = DateTime.now.strftime('%Q')
    payload = { "status_code": 200, "tweet_id": fake_tweet_id, "note_id": note.id }
    command_payload = sample_twitter_reply_acknowledgement(@account, @handle, @stream, payload)
    push_to_channel(command_payload)

    tweet = @account.tweets.last
    assert_equal tweet[:tweetable_id], payload[:note_id]
    assert_equal tweet[:tweet_id].to_s, payload[:tweet_id]
  end

  def test_update_social_tweets_for_mention
    note = create_twitter_ticket_and_note('mention')
    fake_tweet_id = DateTime.now.strftime('%Q')
    payload = { 'status_code': 200, 'tweet_id': fake_tweet_id, 'note_id': note.id, 'tweet_type': 'mention' }
    command_payload = sample_twitter_reply_acknowledgement(@account, @handle, @stream, payload)
    push_to_channel(command_payload)

    tweet = @account.tweets.last
    assert_equal tweet[:tweetable_id], payload[:note_id]
    assert_equal tweet[:tweet_id].to_s, payload[:tweet_id]
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
    Ryuken::ChannelMessagePoller.new.perform(sqs_payload, nil)
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

  def test_facebook_receive_create_ticket
    fb_page = create_facebook_page
    Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new({status: 202}))
    sqs_body = get_fb_create_ticket_command(fb_page.page_id)
    @account.reload
    old_tickets_count = @account.tickets.count
    push_to_channel(sqs_body)
    @account.reload
    ticket = @account.tickets.last
    last_fb_post = fb_page.fb_posts.find_by_post_id(sqs_body[:payload][:context][:post_id])
    new_tickets_count = @account.tickets.count

    assert_equal ticket.id, last_fb_post.postable_id
    assert_equal 'ad_post', last_fb_post.msg_type
    assert_equal old_tickets_count + 1, new_tickets_count
  ensure
    ticket.destroy
    Faraday::Connection.any_instance.unstub(:post)
  end

  def test_facebook_receive_create_ticket_with_product_id
    fb_page = create_facebook_page
    Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new(status: 202))
    sqs_body = get_fb_create_ticket_command(fb_page.page_id)
    @account.reload
    push_to_channel(sqs_body)
    @account.reload
    ticket = @account.tickets.last
    assert_equal ticket.product_id, fb_page.product_id
  ensure
    ticket.destroy
    Faraday::Connection.any_instance.unstub(:post)
  end

  def test_facebook_receive_create_ticket_with_conflict
    fb_page = create_facebook_page
    Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new(status: 202))
    sqs_body = get_fb_create_ticket_command(fb_page.page_id)
    @account.reload
    old_tickets_count = @account.tickets.count
    push_to_channel(sqs_body)
    push_to_channel(sqs_body)
    @account.reload
    ticket = @account.tickets.last
    last_fb_post = fb_page.fb_posts.find_by_post_id(sqs_body[:payload][:context][:post_id])
    new_tickets_count = @account.tickets.count

    assert_equal ticket.id, last_fb_post.postable_id
    assert_equal old_tickets_count + 1, new_tickets_count

    conflict_result = ChannelIntegrations::Commands::Processor.new.process(sqs_body[:payload])
    assert_equal conflict_result[:data][:id], last_fb_post.postable.display_id
    assert_equal conflict_result[:status_code], 409
  end

  def test_facebook_receive_create_note_command
    fb_page = create_facebook_page
    Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new({status: 202}))
    ticket = create_ticket_from_fb_post
    old_notes_count = @account.notes.count
    note_sqs_body = get_fb_create_note_command(fb_page.page_id, ticket.display_id)
    push_to_channel(note_sqs_body)
    @account.reload
    note = @account.notes.last
    last_fb_post_after_note_added = fb_page.fb_posts.find_by_post_id (note_sqs_body[:payload][:context][:post_id])
    new_notes_count = @account.notes.count


    assert_equal note.id, last_fb_post_after_note_added.postable_id
    assert_equal 'ad_post', last_fb_post_after_note_added.msg_type
    assert_equal old_notes_count + 1, new_notes_count
  ensure
    note.destroy
    ticket.destroy
    Faraday::Connection.any_instance.unstub(:post)
  end

  def test_facebook_receive_create_note_with_conflict
    fb_page = create_facebook_page
    Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new(status: 202))
    ticket = create_ticket_from_fb_post
    old_notes_count = @account.notes.count
    note_sqs_body = get_fb_create_note_command(fb_page.page_id, ticket.display_id)
    push_to_channel(note_sqs_body)
    push_to_channel(note_sqs_body)
    @account.reload
    note = @account.notes.last
    last_fb_post_after_note_added = fb_page.fb_posts.find_by_post_id (note_sqs_body[:payload][:context][:post_id])
    new_notes_count = @account.notes.count

    assert_equal note.id, last_fb_post_after_note_added.postable_id
    assert_equal old_notes_count + 1, new_notes_count

    conflict_result = ChannelIntegrations::Commands::Processor.new.process(note_sqs_body[:payload])
    assert_equal conflict_result[:data][:id], last_fb_post_after_note_added.postable_id
    assert_equal conflict_result[:status_code], 409
  ensure
    note.destroy
    ticket.destroy
    Faraday::Connection.any_instance.unstub(:post)
  end

  def test_receive_create_ticket_when_fb_page_not_present
    assert_nothing_raised do
      Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new({status: 202}))
      sqs_body = get_fb_create_ticket_command(123)
      @account.reload
      old_tickets_count = @account.tickets.count
      push_to_channel(sqs_body)
      @account.reload
      new_tickets_count = @account.tickets.count

      assert_equal old_tickets_count, new_tickets_count
    end
  ensure
    Faraday::Connection.any_instance.unstub(:post)
  end

  def test_receive_create_ticket_when_requester_record_not_present
    assert_nothing_raised do
      fb_page = create_facebook_page
      Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new({status: 202}))
      sqs_body = get_fb_create_ticket_command(fb_page.page_id, @account.users.last.id + 999)
      @account.reload
      old_tickets_count = @account.tickets.count
      push_to_channel(sqs_body)
      @account.reload
      new_tickets_count = @account.tickets.count

      assert_equal old_tickets_count, new_tickets_count
    end
  ensure
    Faraday::Connection.any_instance.unstub(:post)
  end

  def test_receive_create_note_when_ticket_not_present
    assert_nothing_raised do
      fb_page = create_facebook_page
      Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new({status: 202}))
      ticket_id = @account.tickets.last.display_id + 1
      note_sqs_body = get_fb_create_note_command(fb_page.page_id, ticket_id)
      old_note_count = @account.notes.count
      push_to_channel(note_sqs_body)
      @account.reload
      new_note_count = @account.notes.count
      assert_equal old_note_count, new_note_count
    end
  ensure
    Faraday::Connection.any_instance.unstub(:post)
  end

  def test_receive_reauth_facebook_page
    fb_page = create_facebook_page
    Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new(status: 202))
    sqs_body = get_fb_reauth_required_command(fb_page.page_id, true, true)
    push_to_channel(sqs_body)
    @account.reload
    fb_page.reload
    assert_equal true, fb_page.reauth_required
  end

  def test_receive_reauth_facebook_page_no_page
    assert_nothing_raised do
      fb_page = create_facebook_page
      Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new(status: 202))
      sqs_body = get_fb_reauth_required_command(fb_page.page_id, true, false)
      push_to_channel(sqs_body)
      @account.reload
      fb_page.reload
      assert_equal false, fb_page.reauth_required
    end
  end

  def test_receive_reauth_facebook_page_no_data
    assert_nothing_raised do
      fb_page = create_facebook_page
      Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new(status: 202))
      sqs_body = get_fb_reauth_required_command(fb_page.page_id, false, true)
      push_to_channel(sqs_body)
      @account.reload
      fb_page.reload
      assert_equal false, fb_page.reauth_required
    end
  end

  def test_receive_reauth_facebook_page_invalid_page
    assert_nothing_raised do
      fb_page = create_facebook_page
      Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new(status: 202))
      sqs_body = get_fb_reauth_required_command(0, true, true)
      push_to_channel(sqs_body)
      @account.reload
      fb_page.reload
      assert_equal false, fb_page.reauth_required
    end
  end

  private

    def twitter_create_ticket_command(tweet_type)
      user = create_twitter_user
      payload = {
        "subject": SecureRandom.uuid,
        "description": Faker::Lorem.characters(100),
        "requester_id": user.id,
        "tweet_type": tweet_type,
        "tweet_id": Faker::Number.between(1, 999_999_999).to_s,
        "contact_twitter_user_id": Faker::Number.between(1, 999_999_999).to_s
      }
      [payload, sample_twitter_create_ticket_command(@account, @handle, @stream, payload)]
    end

    def twitter_create_note_command(tweet_type = 'dm',archive_ticket = false)
      tweet = @account.tweets.where(tweetable_type: 'Helpdesk::Ticket').last

      if tweet && tweet.tweetable_id
        ticket_id = @account.tickets.find(tweet.tweetable_id).display_id
      else
        payload, command_payload = twitter_create_ticket_command(tweet_type)
        push_to_channel(command_payload)
        ticket_id = @account.tickets.last.display_id
      end

      if archive_ticket
        ticket = @account.tickets.find_by_display_id(ticket_id)
        ticket.updated_at = TICKET_UPDATED_DATE
        ticket.status = 5
        ticket.save!
        convert_ticket_to_archive(ticket)
      end

      # create a twitter contact and pass the ID to the user_id here.
      user = create_twitter_user
      payload = {
        "body": Faker::Lorem.characters(100),
        "user_id": user.id,
        "ticket_id": ticket_id,
        "tweet_type": tweet_type,
        "tweet_id": SecureRandom.hex,
        "contact_twitter_user_id": Faker::Number.between(1, 999_999_999).to_s
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
      Ryuken::ChannelMessagePoller.new.perform(sqs_msg, nil)
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

    def get_fb_create_ticket_command(page_id, requester_id = @account.users.first.id)
      {
        "msg_id": Faker::Lorem.characters(10),
        "payload_type": "helpkit_command",
        "account_id": @account.id,
        "payload": {
          "owner": "facebook",
          "client": "helpkit",
          "account_id": @account.id,
          "domain": @account.full_domain,
          "pod": "development",
          "context": {
            "pod": "production",
            "stream_id": "68",
            "post_id": rand(100).to_s,
            "post_type": "ad_post",
            "facebook_page_id": page_id,
            "fbms_stream_id": 1,
            'contact_facebook_user_id': '323232',
            'parent_post_id': 12
          },
          "data": {
            "subject": "Sample Subject",
            "requester_id": requester_id,
            "group_id": "10",
            "product_id": "12",
            "description": "<div>Test Description</div>",
            "status": 2,
            "created_at": Time.now.utc.iso8601,
            "priority": 1
          },
          "meta": {
            "fallbackToReplyQueue": false,
            "timeout": 30000,
            "waitForReply": false
          },
            "command_name": "create_ticket",
            "command_id": Faker::Lorem.characters(10),
            "schema_version": 1
          }
      }
    end

    def get_fb_create_note_command(page_id, ticket_id)
      {
        "msg_id": Faker::Lorem.characters(10),
        "payload_type": "helpkit_command",
        "account_id": "1",
        "payload": {
          "owner":"facebook",
          "client":"helpkit",
          "account_id":@account.id,
          "domain": @account.full_domain,
          "pod":"development",
          "context":{
            "pod": "production",
            "stream_id":"68",
            "post_id":"1006",
            "post_type":"ad_post",
            "facebook_page_id": page_id,
            "fbms_stream_id": 1,
            'contact_facebook_user_id': '323232',
            'parent_post_id': 12
          },
          "data": {
            "body": "<div>Hi</div>",
            "user_id": @account.users.first.id,
            "ticket_id": ticket_id,
            "incoming": true,
            "created_at": Time.now.utc.iso8601,
            "private": true
          },
          "meta": {
            "fallbackToReplyQueue": false,
            "timeout": 30000,
            "waitForReply": false
          },
          "command_name": "create_note",
          "command_id": Faker::Lorem.characters(10),
          "schema_version": 1
        }
      }
    end

    def get_fb_reauth_required_command(page_id, data_required, context_required)
      {
        "msg_id": Faker::Lorem.characters(10),
        "payload_type": 'helpkit_command',
        "account_id": '1',
        "payload": {
          "owner": 'facebook',
          "client": 'helpkit',
          "account_id": @account.id,
          "domain": @account.full_domain,
          "pod": 'development',
          "context": get_reauth_context(context_required, page_id),
          "data": get_reauth_data(data_required),
          "meta": {
            "fallbackToReplyQueue": false,
            "timeout": 300_00,
            "waitForReply": false
          },
          "command_name": 'reauth_facebook_page',
          "command_id": Faker::Lorem.characters(10),
          "schema_version": 1
        }
      }
    end

    def get_reauth_context(context, page_id)
      context ? { "facebook_page_id": page_id } : {}
    end

    def get_reauth_data(data)
      data ? { "reauth_required": true } : {}
    end
end
