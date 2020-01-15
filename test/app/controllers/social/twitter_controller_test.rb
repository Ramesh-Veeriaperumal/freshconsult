require_relative '../../../api/test_helper'
require_relative '../../../core/helpers/users_test_helper'
['account_test_helper.rb', 'twitter_test_helper'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['twitter_helper.rb', 'social_tickets_creation_helper.rb', 'dynamo_helper.rb', 'gnip_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class Social::TwitterControllerTest < ActionController::TestCase
  
  include TwitterHelper
  include Social::Twitter::Constants
  include AccountTestHelper
  include SocialTestHelper
  include SocialTicketsCreationHelper
  include CoreUsersTestHelper
  include DynamoHelper
  include TwitterTestHelper
  include GnipHelper

  def setup
    super
    account = current_account
    @handle = get_twitter_handle
    @default_stream = @handle.default_stream
    @data = @default_stream.data
    @rule = {:rule_value => @data[:rule_value], :rule_tag => @data[:rule_tag]}
  end

  def current_account
    Account.first || create_test_account
  end

  def test_twitter_convert_to_ticket_from_social_tab
    user = Account.current.account_managers.first.make_current
    @controller.stubs(:current_user).returns(user)
    tweet_id = (Time.now.utc.to_f*100000).to_i
    AWS::DynamoDB::ClientV2.any_instance.stubs(:query).returns(sample_dynamo_query_params)
    Social::DynamoHelper.stubs(:get_item).returns(sample_dynamo_get_item_params)
    Social::DynamoHelper.stubs(:batch_get).returns(sample_interactions_batch_get(tweet_id))
    Account.current.stubs(:incoming_mentions_in_tms_enabled?).returns(false)
    @request.env['HTTP_ACCEPT'] = 'application/json'
    Social::SmartFilterFeedbackWorker.jobs.clear
    with_twitter_update_stubbed do
      sample_gnip_feed = sample_gnip_feed(@rule, nil, Time.now.utc.iso8601)
      sample_gnip_feed["id"] = "tag:search.twitter.com,2005:#{tweet_id}"
      @account = Account.current
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      assert_equal tweet, nil

      stream_id = "#{@account.id}_#{@default_stream.id}"
      fd_item_params = sample_params_fd_item("#{tweet_id}", stream_id, SEARCH_TYPE[:saved], "#{tweet_id}")
      fd_item_params[:item][:text] = sample_gnip_feed["body"]
      post :create_fd_item, fd_item_params

      sidekiq_jobs = Social::SmartFilterFeedbackWorker.jobs
      assert_equal 1, sidekiq_jobs.size
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      assert_not_nil tweet
      assert_equal tweet.is_ticket?, true
    end
  ensure
    Account.current.unstub(:incoming_mentions_in_tms_enabled?)
    @controller.unstub(:current_user)
    AWS::DynamoDB::ClientV2.unstub(:query)
    Social::DynamoHelper.unstub(:get_item)
    Social::DynamoHelper.unstub(:batch_get)
    Social::SmartFilterFeedbackWorker.jobs.clear
  end

  def test_twitter_convert_to_ticket_from_social_tab_with_incoming_in_tms_feature_enabled
    user = Account.current.account_managers.first.make_current
    @controller.stubs(:current_user).returns(user)
    tweet_id = (Time.now.utc.to_f*100000).to_i
    AWS::DynamoDB::ClientV2.any_instance.stubs(:query).returns(sample_dynamo_query_params)
    Social::DynamoHelper.stubs(:get_item).returns(sample_dynamo_get_item_params)
    Social::DynamoHelper.stubs(:batch_get).returns(sample_interactions_batch_get(tweet_id))
    Account.current.launch(:incoming_mentions_in_tms)
    @request.env['HTTP_ACCEPT'] = 'application/json'
    Social::SmartFilterFeedbackWorker.jobs.clear
    with_twitter_update_stubbed do
      sample_gnip_feed = sample_gnip_feed(@rule, nil, Time.now.utc.iso8601)
      sample_gnip_feed["id"] = "tag:search.twitter.com,2005:#{tweet_id}"
      @account = Account.current
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      assert_equal tweet, nil

      stream_id = "#{@account.id}_#{@default_stream.id}"
      fd_item_params = sample_params_fd_item("#{tweet_id}", stream_id, SEARCH_TYPE[:saved], "#{tweet_id}")
      fd_item_params[:item][:text] = sample_gnip_feed["body"]
      post :create_fd_item, fd_item_params

      sidekiq_jobs = Social::SmartFilterFeedbackWorker.jobs
      assert_equal 0, sidekiq_jobs.size
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      assert_not_nil tweet
      assert_equal tweet.is_ticket?, true
    end
  ensure
    Account.current.rollback(:incoming_mentions_in_tms)
    @controller.unstub(:current_user)
    AWS::DynamoDB::ClientV2.unstub(:query)
    Social::DynamoHelper.unstub(:get_item)
    Social::DynamoHelper.unstub(:batch_get)
    Social::SmartFilterFeedbackWorker.jobs.clear
  end

  def test_twitter_reply_to_tweet_ticket_from_social_tab
    user = Account.current.account_managers.first.make_current
    @controller.stubs(:current_user).returns(user)
    @request.env['HTTP_ACCEPT'] = 'application/json'
    with_twitter_update_stubbed do
      ticket = create_twitter_ticket
      @account = Account.current
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130],
          in_reply_to: ticket.tweet.tweet_id
        },
        twitter_handle_id: @handle.id,
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
    User.any_instance.unstub(:privilege?)
    @controller.unstub(:current_user)
  end

  def test_twitter_reply_to_non_ticket_tweet_from_social_tab
    user = Account.current.account_managers.first.make_current
    @controller.stubs(:current_user).returns(user)
    @request.env['HTTP_ACCEPT'] = 'application/json'
    with_twitter_update_stubbed do
      @account = Account.current
      params_hash = {
        tweet: {
          body: Faker::Lorem.sentence[0..130]
        },
        twitter_handle_id: @handle.id,
        search_type: 'streams'
      }
      User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(true)
      post :reply, params_hash, format: 'js'
      assert_response 200
    end
  ensure
    User.any_instance.unstub(:privilege?)
    @controller.unstub(:current_user)
  end
end
