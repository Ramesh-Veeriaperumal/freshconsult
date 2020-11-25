# frozen_string_literal:true

require_relative '../../../api/api_test_helper'
require_relative '../../../core/helpers/users_test_helper'
['account_test_helper.rb', 'twitter_test_helper'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['twitter_helper.rb', 'social_tickets_creation_helper.rb', 'dynamo_helper.rb', 'gnip_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class Social::TiwtterControllerFlowTest < ActionDispatch::IntegrationTest
  include TwitterHelper
  include Social::Twitter::Constants
  include Mobile::Constants
  include AccountTestHelper
  include SocialTestHelper
  include SocialTicketsCreationHelper
  include CoreUsersTestHelper
  include DynamoHelper
  include TwitterTestHelper
  include GnipHelper

  def setup
    super
    @handle = create_test_twitter_handle(@account)
    @default_stream = create_test_custom_twitter_stream(@handle)
    @data = @default_stream.data
    @rule = { rule_value: @data[:rule_value], rule_tag: @data[:rule_tag] }
  end

  def test_post_tweet_from_social_tab
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, sample_twitter_tweet_object])
    with_twitter_update_stubbed do
      params_hash = {
        tweet: {
          body: Faker::Lorem.words(10).join(' ')
        },
        format: 'js',
        twitter_handle_id: @handle.id
      }
      Social::TwitterHandle.any_instance.stubs(:default_stream).returns(@default_stream)
      post '/social/twitter/post_tweet', params_hash
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.tweeted'), flash[:notice], 'Your tweet has been sent.'
    end
  ensure
    Social::TwitterHandle.any_instance.unstub(:default_stream)
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_unfollow_option_from_social_tab
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      to_unfollow_handle = create_test_twitter_handle(@account)
      post '/social/twitter/unfollow', sample_follow_params(to_unfollow_handle, @handle)
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.unfollow_success'), flash[:notice], 'Unfollowed'
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_follow_option_from_social_tab
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      to_follow_handle = create_test_twitter_handle(@account)
      post '/social/twitter/follow', sample_follow_params(to_follow_handle, @handle)
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.follow_success'), flash[:notice], 'Followed'
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_get_retweets
    Twitter::REST::Client.any_instance.stubs(:status).returns(sample_twitter_tweet_object)
    Twitter::REST::Client.any_instance.stubs(:retweets).returns([sample_twitter_tweet_object])
    with_twitter_update_stubbed do
      get '/social/twitter/retweets', retweeted_id: @twit.id.to_s, format: 'js'
      assert_response 200
    end
  ensure
    Twitter::REST::Client.unstub(:status)
    Twitter::REST::Client.unstub(:retweets)
  end

  def test_twitter_get_followers_from_social_tab
    Social::Twitter::User.stubs(:get_followers).returns([nil, sample_follower_ids.attrs[:ids]])
    with_twitter_update_stubbed do
      Social::TwitterStream.any_instance.stubs(:default_stream?).returns(true)
      get '/social/twitter/followers', screen_name: Faker::Name.first_name, format: 'js'
      assert_response 200
    end
  ensure
    Social::TwitterStream.any_instance.unstub(:default_stream?)
    Social::Twitter::User.unstub(:get_followers)
  end

  def test_twitter_get_followers_from_social_tab_with_no_followers
    Social::Twitter::User.stubs(:get_followers).returns([nil, nil])
    with_twitter_update_stubbed do
      get '/social/twitter/followers', screen_name: Faker::Name.first_name, format: 'js'
      assert_response 200
    end
  ensure
    Social::Twitter::User.unstub(:get_followers)
  end

  def test_twitter_follow_with_blank_follow_status
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, nil])
    with_twitter_update_stubbed do
      to_follow_handle = create_test_twitter_handle(@account)
      post '/social/twitter/follow', sample_follow_params(to_follow_handle, @handle)
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.already_followed'), flash[:notice], 'Followed Already'
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_follow_without_global_access
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      stream_id = "#{@account.id}_#{@default_stream.id}"
      Helpdesk::Access.any_instance.stubs(:global_access_type?).returns(false)
      to_follow_handle = create_test_twitter_handle(@account)
      params_hash = sample_follow_params(to_follow_handle, @handle)
      params_hash[:user][:stream_id] = stream_id
      post '/social/twitter/follow', params_hash
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.cannot_follow'), flash[:notice], 'You dont have permission to follow this user.'
    end
  ensure
    Helpdesk::Access.any_instance.unstub(:global_access_type?)
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_show_old
    Social::Twitter::Feed.stubs(:fetch_tweets).returns([nil, '', [], '', '', ''])
    with_twitter_update_stubbed do
      stream_id = "#{@account.id}_#{@default_stream.id}"
      params_hash = {
        max_id: '',
        q: '',
        include_entities: '1',
        search: {
          q: ['Hello world'],
          stream_id: stream_id,
          next_results: '',
          refresh_url: ''
        },
        format: 'js'
      }
      get '/social/twitter/show_old', params_hash
      assert_response 200
    end
  ensure
    Social::Twitter::Feed.unstub(:fetch_tweets)
  end

  def test_twitter_unfollow_with_blank_unfollow_status
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, nil])
    with_twitter_update_stubbed do
      to_unfollow_handle = create_test_twitter_handle(@account)
      post '/social/twitter/unfollow', sample_follow_params(to_unfollow_handle, @handle)
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.already_unfollowed'), flash[:notice], 'Unfollwed Already'
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_unfollow_without_global_access
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      stream_id = "#{@account.id}_#{@default_stream.id}"
      to_unfollow_handle = create_test_twitter_handle(@account)
      Helpdesk::Access.any_instance.stubs(:global_access_type?).returns(false)
      params_hash = sample_follow_params(to_unfollow_handle, @handle)
      params_hash[:user][:stream_id] = stream_id
      post '/social/twitter/unfollow', params_hash
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.cannot_unfollow'), flash[:notice], 'You dont have permission to unfollow this user.'
    end
  ensure
    Helpdesk::Access.any_instance.unstub(:global_access_type?)
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_search
    Social::Twitter::Feed.stubs(:fetch_tweets).returns([nil, '', [], '', '', ''])
    with_twitter_update_stubbed do
      stream_id = "#{@account.id}_#{@default_stream.id}"
      params_hash = {
        search: {
          q: ['Hello world'],
          stream_id: stream_id,
          type: SEARCH_TYPE[:live],
          next_results: '',
          refresh_url: ''
        },
        format: 'js'
      }
      get '/social/twitter/twitter_search', params_hash
      assert_response 200
    end
  ensure
    Social::Twitter::Feed.unstub(:fetch_tweets)
  end

  def test_post_tweet_from_mobile
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, sample_twitter_tweet_object])
    with_twitter_update_stubbed do
      params_hash = {
        tweet: {
          body: Faker::Lorem.words(10).join(' ')
        },
        format: 'nmobile',
        twitter_handle_id: @handle.id
      }
      Social::TwitterHandle.any_instance.stubs(:default_stream).returns(@default_stream)
      post '/social/twitter/post_tweet', params_hash
      assert_response 200
      assert_equal JSON.parse(@response.body)['message'], MOBILE_TWITTER_RESPONSE_CODES[:tweeted]
      assert JSON.parse(@response.body)['result']
    end
  ensure
    Social::TwitterHandle.any_instance.unstub(:default_stream)
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_post_tweet_without_global_access
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, sample_twitter_tweet_object])
    with_twitter_update_stubbed do
      params_hash = {
        tweet: {
          body: Faker::Lorem.words(10).join(' ')
        },
        format: 'js',
        twitter_handle_id: @handle.id
      }
      Social::TwitterHandle.any_instance.stubs(:default_stream).returns(@default_stream)
      Helpdesk::Access.any_instance.stubs(:global_access_type?).returns(false)
      post '/social/twitter/post_tweet', params_hash
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.cannot_post'), flash[:notice], 'You dont have permission to tweet.'
    end
  ensure
    Social::TwitterHandle.any_instance.unstub(:default_stream)
    Helpdesk::Access.any_instance.unstub(:global_access_type?)
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_post_tweet_from_social_tab_with_invalid_length
    with_twitter_update_stubbed do
      params_hash = {
        tweet: {
          body: Faker::Lorem.characters(10_001)
        },
        format: 'js',
        twitter_handle_id: @handle.id
      }
      Social::TwitterHandle.any_instance.stubs(:default_stream).returns(@default_stream)
      post '/social/twitter/post_tweet', params_hash
      assert_response 200
      assert_equal I18n.t(:'twitter.not_valid'), flash[:notice], 'Status is over 280 characters.'
    end
  ensure
    Social::TwitterHandle.any_instance.unstub(:default_stream)
  end

  def test_post_tweet_from_social_tab_when_twitter_unstable
    Social::Twitter::Feed.stubs(:twitter_action).returns([I18n.t(:'twitter.error_sending'), nil])
    with_twitter_update_stubbed do
      params_hash = {
        tweet: {
          body: Faker::Lorem.words(10).join(' ')
        },
        format: 'js',
        twitter_handle_id: @handle.id
      }
      Social::TwitterHandle.any_instance.stubs(:default_stream).returns(@default_stream)
      post '/social/twitter/post_tweet', params_hash
      assert_response 200
      assert_equal I18n.t(:'twitter.error_sending'), flash[:notice], 'Error sending the tweet! Twitter might be unstable. Please try again.'
    end
  ensure
    Social::TwitterHandle.any_instance.unstub(:default_stream)
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_fetch_new
    Social::Twitter::Feed.stubs(:fetch_tweets).returns([nil, '', [], '', '', ''])
    with_twitter_update_stubbed do
      stream_id = "#{@account.id}_#{@default_stream.id}"
      params_hash = {
        search: {
          q: ['Hello world'],
          stream_id: stream_id,
          next_results: '',
          refresh_url: ''
        },
        format: 'js'
      }
      get '/social/twitter/fetch_new', params_hash
      assert_response 200
    end
  ensure
    Social::Twitter::Feed.unstub(:fetch_tweets)
  end

  def test_user_following
    Twitter::REST::Client.any_instance.stubs(:friendship?).returns(true)
    with_twitter_update_stubbed do
      params_hash = {
        twitter_handle: @handle.id,
        req_twt_id: 'TestingTwitter'
      }
      post '/social/twitter/user_following', params_hash
      assert_response 200
      assert JSON.parse(@response.body)['user_follows']
    end
  ensure
    Twitter::REST::Client.any_instance.unstub(:friendship?)
  end

  def test_twitter_reply_to_tweet_ticket_with_invalid_length
    with_twitter_update_stubbed do
      ticket = create_twitter_ticket
      params_hash = {
        tweet:
        {
          body: Faker::Lorem.sentence(300),
          in_reply_to: ticket.tweet.tweet_id
        },
        twitter_handle_id: @handle.id,
        search_type: 'streams',
        format: 'js'
      }
      post '/social/twitter/reply', params_hash
      assert_response 200
      assert_equal I18n.t(:'twitter.not_valid'), flash[:notice], 'Status is over 280 characters.'
    end
  end

  def test_twitter_reply_to_tweet_ticket_from_social_tab_from_mobile
    with_twitter_update_stubbed do
      ticket = create_twitter_ticket
      stream_id = "#{@account.id}_#{@default_stream.id}"
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130],
          in_reply_to: ticket.tweet.tweet_id
        },
        format: 'nmobile',
        twitter_handle_id: @handle.id,
        search_type: 'streams',
        stream_id: stream_id
      }
      Social::TwitterHandle.any_instance.stubs(:default_stream).returns(@default_stream)
      post '/social/twitter/reply', params_hash
      assert_response 200
      latest_note = ticket.notes.last
      tweet = latest_note.tweet
      assert_equal tweet.tweet_id.negative?, true, 'Tweet id should be less than zero'
      assert_equal tweet.stream_id, @default_stream.id
    end
  ensure
    Social::TwitterHandle.any_instance.unstub(:default_stream)
  end

  def test_twitter_reply_to_tweet_ticket_without_global_access
    with_twitter_update_stubbed do
      ticket = create_twitter_ticket
      stream_id = "#{@account.id}_#{@default_stream.id}"
      Helpdesk::Access.any_instance.stubs(:global_access_type?).returns(false)
      params_hash = sample_tweet_reply(stream_id, ticket.tweet.tweet_id, SEARCH_TYPE[:saved]).merge(format: 'js')
      post '/social/twitter/reply', params_hash
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.cannot_reply'), flash[:notice], 'You dont have permission to reply to a tweet.'
    end
  ensure
    Helpdesk::Access.any_instance.unstub(:global_access_type?)
  end

  def test_twitter_reply_to_tweet_ticket_with_invalid_note
    with_twitter_update_stubbed do
      ticket = create_twitter_ticket
      stream_id = "#{@account.id}_#{@default_stream.id}"
      Helpdesk::Note.any_instance.stubs(:save_note).returns(false)
      Social::TwitterHandle.any_instance.stubs(:default_stream).returns(@default_stream)
      params_hash = sample_tweet_reply(stream_id, ticket.tweet.tweet_id, SEARCH_TYPE[:saved]).merge(format: 'js')
      post '/social/twitter/reply', params_hash
      assert_response 200
    end
  ensure
    Social::TwitterHandle.any_instance.unstub(:default_stream)
    Helpdesk::Note.any_instance.unstub(:save_note)
  end

  def test_twitter_reply_to_non_ticket_tweet_with_custom_search_type
    with_twitter_update_stubbed do
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130]
        },
        twitter_handle_id: @handle.id,
        search_type: SEARCH_TYPE[:custom],
        format: 'js'
      }
      post '/social/twitter/reply', params_hash
      assert_response 200
    end
  end

  def test_twitter_reply_to_non_ticket_tweet_without_handle
    with_twitter_update_stubbed do
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130]
        },
        twitter_handle_id: nil,
        search_type: SEARCH_TYPE[:custom],
        format: 'js'
      }
      post '/social/twitter/reply', params_hash
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.feeds_blank'), flash[:notice], 'Please add a twitter handle to your account to fetch your custom stream.'
    end
  end

  def test_twitter_reply_to_non_ticket_tweet_with_invalid_length
    with_twitter_update_stubbed do
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence(300)
        },
        twitter_handle_id: @handle.id,
        search_type: SEARCH_TYPE[:custom],
        format: 'js'
      }
      post '/social/twitter/reply', params_hash
      assert_response 200
      assert_equal I18n.t(:'twitter.not_valid'), flash[:notice], 'Status is over 280 characters.'
    end
  end

  def test_twitter_user_info
    Twitter::REST::Client.any_instance.stubs(:users).returns([sample_twitter_user((Time.now.utc.to_f * 100_000).to_i)])
    with_twitter_update_stubbed do
      params_hash = {
        user: {
          name: 'GnipTesting',
          screen_name: '@GnipTesting',
          normal_img_url: 'https://si0.twimg.com/profile_images/2816192909/db88b820451fa8498e8f3cf406675e13_normal.png'
        },
        format: 'js'
      }
      User.any_instance.stubs(:visible_twitter_streams).returns([])
      get '/social/twitter/user_info', params_hash
      assert_response 200
    end
  ensure
    User.any_instance.unstub(:visible_twitter_streams)
    Twitter::REST::Client.any_instance.unstub(:users)
  end

  def test_twitter_add_to_favourites_option_with_blank_favorite_status
    tweet_id = (Time.now.utc.to_f * 100_000).to_i
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, nil])
    with_twitter_update_stubbed do
      tweet = @account.tweets.where(tweet_id: tweet_id).first
      assert_equal tweet, nil
      stream_id = "#{@account.id}_#{@default_stream.id}"
      favourite_params = sample_favourite_params(tweet_id.to_s, stream_id).merge(format: 'js')
      post '/social/twitter/favorite', favourite_params
      assert_response 200
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_add_to_favourites_option_from_mobile
    tweet_id = (Time.now.utc.to_f * 100_000).to_i
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      tweet = @account.tweets.where(tweet_id: tweet_id).first
      assert_equal tweet, nil
      stream_id = "#{@account.id}_#{@default_stream.id}"
      favourite_params = sample_favourite_params(tweet_id.to_s, stream_id).merge(format: 'nmobile')
      post '/social/twitter/favorite', favourite_params
      assert_response 200
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_add_to_favourites_without_global_access
    tweet_id = (Time.now.utc.to_f * 100_000).to_i
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      tweet = @account.tweets.where(tweet_id: tweet_id).first
      assert_equal tweet, nil
      stream_id = "#{@account.id}_#{@default_stream.id}"
      favourite_params = sample_favourite_params(tweet_id.to_s, stream_id).merge(format: 'js')
      Helpdesk::Access.any_instance.stubs(:global_access_type?).returns(false)
      post '/social/twitter/favorite', favourite_params
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.cannot_favorite'), flash[:notice], 'You dont have permission to favorite a tweet.'
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
    Helpdesk::Access.any_instance.unstub(:global_access_type?)
  end

  def test_twitter_convert_to_ticket_with_invalid_search_type
    tweet_id = (Time.now.utc.to_f * 100_000).to_i
    Aws::DynamoDB::Client.any_instance.stubs(:query).returns(sample_dynamo_query_params)
    Aws::DynamoDB::Client.any_instance.stubs(:get_item).returns(sample_dynamo_get_item_params)
    Aws::DynamoDB::Client.any_instance.stubs(:batch_get_item).returns(sample_interactions_batch_get(tweet_id).first)
    with_twitter_update_stubbed do
      sample_gnip_feed = sample_gnip_feed(@rule, nil, Time.now.utc.iso8601)
      sample_gnip_feed['id'] = "tag:search.twitter.com,2005:#{tweet_id}"
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      assert_equal tweet, nil

      stream_id = "#{@account.id}_#{@default_stream.id}"
      fd_item_params = sample_params_fd_item(tweet_id.to_s, stream_id, 'invalid_search_type', tweet_id.to_s)
      fd_item_params[:item][:text] = sample_gnip_feed['body']
      post '/social/twitter/create_fd_item', fd_item_params
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      assert_nil tweet
    end
  ensure
    Aws::DynamoDB::Client.any_instance.unstub(:query)
    Aws::DynamoDB::Client.any_instance.unstub(:get_item)
    Aws::DynamoDB::Client.any_instance.unstub(:batch_get_item)
  end

  def test_twitter_convert_to_ticket_without_global_access
    tweet_id = (Time.now.utc.to_f * 100_000).to_i
    Aws::DynamoDB::Client.any_instance.stubs(:query).returns(sample_dynamo_query_params)
    Aws::DynamoDB::Client.any_instance.stubs(:get_item).returns(sample_dynamo_get_item_params)
    Aws::DynamoDB::Client.any_instance.stubs(:batch_get_item).returns(sample_interactions_batch_get(tweet_id).first)
    with_twitter_update_stubbed do
      sample_gnip_feed = sample_gnip_feed(@rule, nil, Time.now.utc.iso8601)
      sample_gnip_feed['id'] = "tag:search.twitter.com,2005:#{tweet_id}"
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      assert_equal tweet, nil

      stream_id = "#{@account.id}_#{@default_stream.id}"
      fd_item_params = sample_params_fd_item(tweet_id.to_s, stream_id, SEARCH_TYPE[:saved], tweet_id.to_s)
      fd_item_params[:item][:text] = sample_gnip_feed['body']
      Helpdesk::Access.any_instance.stubs(:global_access_type?).returns(false)
      post '/social/twitter/create_fd_item', fd_item_params.merge(format: 'js')
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      assert_response 200
      assert_nil tweet
      assert_equal I18n.t(:'social.streams.twitter.cannot_create_fd_item'), flash[:notice], 'You dont have permission to convert a tweet to a ticket / note.'
    end
  ensure
    Helpdesk::Access.any_instance.unstub(:global_access_type?)
    Aws::DynamoDB::Client.any_instance.unstub(:query)
    Aws::DynamoDB::Client.any_instance.unstub(:get_item)
    Aws::DynamoDB::Client.any_instance.unstub(:batch_get_item)
  end

  def test_twitter_convert_to_ticket
    tweet_id = (Time.now.utc.to_f * 100_000).to_i
    Aws::DynamoDB::Client.any_instance.stubs(:query).returns(sample_dynamo_query_params)
    Aws::DynamoDB::Client.any_instance.stubs(:get_item).returns(sample_dynamo_get_item_params)
    Aws::DynamoDB::Client.any_instance.stubs(:batch_get_item).returns(sample_interactions_batch_get(tweet_id).first)
    with_twitter_update_stubbed do
      sample_gnip_feed = sample_gnip_feed(@rule, nil, Time.now.utc.iso8601)
      sample_gnip_feed['id'] = "tag:search.twitter.com,2005:#{tweet_id}"
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      assert_equal tweet, nil

      stream_id = "#{@account.id}_#{@default_stream.id}"
      fd_item_params = sample_params_fd_item(tweet_id.to_s, stream_id, SEARCH_TYPE[:saved], tweet_id.to_s)
      fd_item_params[:item][:text] = sample_gnip_feed['body']
      post '/social/twitter/create_fd_item', fd_item_params.merge(format: 'nmobile')
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      assert_not_nil tweet
      assert_equal tweet.is_ticket?, true
    end
  ensure
    Helpdesk::Access.any_instance.unstub(:global_access_type?)
    Aws::DynamoDB::Client.any_instance.unstub(:query)
    Aws::DynamoDB::Client.any_instance.unstub(:get_item)
    Aws::DynamoDB::Client.any_instance.unstub(:batch_get_item)
  end

  def test_twitter_add_to_unfavourites_option_from_social_tab
    tweet_id = (Time.now.utc.to_f * 100_000).to_i
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      tweet = @account.tweets.where(tweet_id: tweet_id).first
      assert_equal tweet, nil
      stream_id = "#{@account.id}_#{@default_stream.id}"
      favourite_params = sample_favourite_params(tweet_id.to_s, stream_id).merge(format: 'js')
      post '/social/twitter/unfavorite', favourite_params
      assert_response 200
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_add_to_unfavourites_option_with_blank_unfavorite_status
    tweet_id = (Time.now.utc.to_f * 100_000).to_i
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, nil])
    with_twitter_update_stubbed do
      tweet = @account.tweets.where(tweet_id: tweet_id).first
      assert_equal tweet, nil
      stream_id = "#{@account.id}_#{@default_stream.id}"
      favourite_params = sample_favourite_params(tweet_id.to_s, stream_id).merge(format: 'nmobile')
      post '/social/twitter/unfavorite', favourite_params
      assert_response 200
      assert_equal JSON.parse(@response.body)['message'], MOBILE_TWITTER_RESPONSE_CODES[:unfavorite_error]
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_add_to_unfavourites_option_from_mobile
    tweet_id = (Time.now.utc.to_f * 100_000).to_i
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      tweet = @account.tweets.where(tweet_id: tweet_id).first
      assert_equal tweet, nil
      stream_id = "#{@account.id}_#{@default_stream.id}"
      favourite_params = sample_favourite_params(tweet_id.to_s, stream_id).merge(format: 'nmobile')
      post '/social/twitter/unfavorite', favourite_params
      assert_response 200
      assert_equal JSON.parse(@response.body)['message'], MOBILE_TWITTER_RESPONSE_CODES[:unfavorite_success]
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_add_to_unfavourites_without_global_access
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      stream_id = "#{@account.id}_#{@default_stream.id}"
      favourite_params = sample_favourite_params(nil, stream_id).merge(format: 'js')
      Helpdesk::Access.any_instance.stubs(:global_access_type?).returns(false)
      post '/social/twitter/unfavorite', favourite_params
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.cannot_unfavorite'), flash[:notice], 'You dont have permission to unfavorite a tweet.'
    end
  ensure
    Helpdesk::Access.any_instance.unstub(:global_access_type?)
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_retweet_option_from_social_tab
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      @account.make_current
      stream_id = "#{@account.id}_#{@default_stream.id}"
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130],
          feed_id: @twit.id
        },
        twitter_handle_id: @handle.id,
        format: 'js',
        stream_id: stream_id
      }
      post '/social/twitter/retweet', params_hash
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.retweet_success'), flash[:notice], 'Retweeted.'
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_retweet_option_from_mobile
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      @account.make_current
      stream_id = "#{@account.id}_#{@default_stream.id}"
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130],
          feed_id: @twit.id
        },
        twitter_handle_id: @handle.id,
        format: 'nmobile',
        stream_id: stream_id
      }
      post '/social/twitter/retweet', params_hash
      assert_response 200
      assert_equal JSON.parse(@response.body)['message'], MOBILE_TWITTER_RESPONSE_CODES[:retweet_success]
      assert JSON.parse(@response.body)['result']
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_multiple_retweet_option_from_social_tab
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, nil])
    with_twitter_update_stubbed do
      stream_id = "#{@account.id}_#{@default_stream.id}"
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130],
          feed_id: @twit.id
        },
        twitter_handle_id: @handle.id,
        stream_id: stream_id,
        format: 'js'
      }
      account_wrap do
        post '/social/twitter/retweet', params_hash
      end
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.already_retweeted'), flash[:notice], 'Tweet has already been retweeted from this account.'
    end
  ensure
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  def test_twitter_retweet_without_global_access
    Social::Twitter::Feed.stubs(:twitter_action).returns([nil, true])
    with_twitter_update_stubbed do
      stream_id = "#{@account.id}_#{@default_stream.id}"
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130],
          feed_id: @twit.id
        },
        twitter_handle_id: @handle.id,
        format: 'js',
        stream_id: stream_id
      }
      Helpdesk::Access.any_instance.stubs(:global_access_type?).returns(false)
      post '/social/twitter/retweet', params_hash
      assert_response 200
      assert_equal I18n.t(:'social.streams.twitter.cannot_retweet'), flash[:notice], 'You dont have permission to retweet a tweet.'
    end
  ensure
    Helpdesk::Access.any_instance.unstub(:global_access_type?)
    Social::Twitter::Feed.unstub(:twitter_action)
  end

  private

    def old_ui?
      true
    end
end
