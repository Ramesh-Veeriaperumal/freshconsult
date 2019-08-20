require_relative '../../../../api/test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Admin::Social::TwitterStreamsControllerTest < ActionController::TestCase
  include SocialTicketsCreationHelper
  include AccountTestHelper
  include TwitterMentionsTestHelper

  def setup
    super
    @handle = create_new_handle
    @stream = create_new_mention_stream(@handle)
    @account.add_feature(:smart_filter)
  end

  def teardown
    @account.revoke_feature(:smart_filter)
  end

  def create_new_mention_stream(twitter_handle)
    twitter_stream = FactoryGirl.build(:seed_mention_twitter_stream)
    twitter_stream.account_id = @account.id
    twitter_stream.social_id = twitter_handle.id
    twitter_stream.save!
    twitter_stream.populate_accessible(Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all])
    twitter_stream
  end

  def create_new_handle
    twitter_handle = FactoryGirl.build(:seed_twitter_handle)
    twitter_handle.account_id = @account.id
    twitter_handle.save!
    twitter_handle
  end

  def test_update_stream_with_keyword_rules
    @handle.smart_filter_enabled = false
    @handle.save
    params = controller_params(construct_stream_update_params(@stream), false)
    put :update, params
    assert_response 302
    assert_equal 1, @stream.rules.count
  end

  def test_update_stream_with_mention_rules
    Account.any_instance.stubs(:twitter_smart_filter_enabled?).returns(true)
    params = controller_params(construct_stream_update_params(@stream), false)
    params[:smart_filter_enabled] = '1'
    put :update, params
    assert_response 302
    assert_equal 2, @stream.rules.count
  ensure
    Account.any_instance.unstub(:twitter_smart_filter_enabled?)
  end

  def test_update_stream_with_smart_filter_rule
    Account.any_instance.stubs(:twitter_smart_filter_enabled?).returns(true)
    params = controller_params(construct_stream_update_params(@stream), false)
    params[:keyword_rules] = '0'
    params[:smart_filter_enabled] = '1'
    params[:social_ticket_rule] = [{ 'ticket_rule_id' => '', 'deleted' => 'true', 'includes' => '', 'group_id' => '' }]
    put :update, params
    assert_response 302
    assert_equal 1, @stream.rules.count
  ensure
    Account.any_instance.unstub(:twitter_smart_filter_enabled?)
  end

  def test_update_stream_when_rules_deleted
    @handle.smart_filter_enabled = false
    @handle.save
    params = controller_params(construct_stream_update_params(@stream), false)
    params[:capture_tweet_as_ticket] = '0'
    put :update, params
    assert_response 302
    assert_equal 0, @stream.rules.count
  end

  def test_update_stream_with_keyword_rules_central_publish
    @account.launch(:mentions_to_tms)
    @handle.smart_filter_enabled = false
    @handle.save
    params = controller_params(construct_stream_update_params(@stream), false)
    post :update, params
    assert_response 302
    assert_equal 1, @stream.rules.count
  ensure
    @account.rollback(:mentions_to_tms)
  end

  def test_update_stream_with_mention_rules_central_publish
    Account.any_instance.stubs(:twitter_smart_filter_enabled?).returns(true)
    @account.launch(:mentions_to_tms)
    params = controller_params(construct_stream_update_params(@stream), false)
    params[:smart_filter_enabled] = '1'
    post :update, params
    assert_response 302
    assert_equal 2, @stream.rules.count
  ensure
    Account.any_instance.unstub(:twitter_smart_filter_enabled?)
    @account.rollback(:mentions_to_tms)
  end

  def test_update_stream_with_smart_filter_rule_central_publish
    Account.any_instance.stubs(:twitter_smart_filter_enabled?).returns(true)
    @account.launch(:mentions_to_tms)
    params = controller_params(construct_stream_update_params(@stream), false)
    params[:keyword_rules] = '0'
    params[:smart_filter_enabled] = '1'
    params[:social_ticket_rule] = [{ 'ticket_rule_id' => '', 'deleted' => 'true', 'includes' => '', 'group_id' => '' }]
    put :update, params
    assert_response 302
    assert_equal 1, @stream.rules.count
  ensure
    Account.any_instance.unstub(:twitter_smart_filter_enabled?)
    @account.rollback(:mentions_to_tms)
  end

  def test_update_stream_when_rules_deleted_central_publish
    @account.launch(:mentions_to_tms)
    @handle.smart_filter_enabled = false
    @handle.save
    params = controller_params(construct_stream_update_params(@stream), false)
    params[:capture_tweet_as_ticket] = '0'
    put :update, params
    assert_response 302
    assert_equal 0, @stream.rules.count
  ensure
    @account.rollback(:mentions_to_tms)
  end
end
