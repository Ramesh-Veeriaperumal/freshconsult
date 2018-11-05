require_relative '../../test_helper'
['twitter_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['account_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

class Ember::TwitterHandlesControllerTest < ActionController::TestCase
  
  include TwitterHelper
  include Social::Twitter::Constants
  include AccountTestHelper

  def cleanup_twitter_handles(account)
    account.twitter_handles.delete_all
    account.tickets.where(source: 5).destroy_all
  end

  def get_follow_params
    @user_twt_account = create_test_twitter_handle
    follower = create_test_account
    @follower_twt_account = create_test_twitter_handle(follower) 
    @screen_name_to_follow = @follower_twt_account.screen_name
    @screen_name = @user_twt_account.screen_name
  end

  def follow
    get_follow_params
    @social_error_msg, follow_status = Social::Twitter::Feed.twitter_action(@follower_twt_account, @screen_name_to_follow, TWITTER_ACTIONS[:follow])
  end

  def test_load_objects
    cleanup_twitter_handles(Account.first)
    get :index, controller_params("id" => 1)
    assert_response 200
  end

  def test_load_object_with_id_nil
    cleanup_twitter_handles(Account.first)
    Twitter::REST::Client.any_instance.stubs(:follow).returns(true)
    Social::Twitter::Feed.stubs(:following?).returns([nil,true])
    follower = create_test_account
    @follower_twt_account = create_test_twitter_handle(follower) 
    @screen_name_to_follow = @follower_twt_account.screen_name
    user_id = Account.last.id + 20
    get :check_following, controller_params("screen_name" => @screen_name_to_follow, "id" => user_id )
    assert_response 404
  ensure
    Twitter::REST::Client.any_instance.unstub(:follow)
    Social::Twitter::Feed.unstub(:following?)
  end

  def test_check_following_with_error
    cleanup_twitter_handles(Account.first)
    get_follow_params
    Social::Twitter::Feed.stubs(:following?).returns(["We could not process your request. Please try after sometime.", false])
    get :check_following, controller_params("screen_name" => @screen_name_to_follow, "id" => @user_twt_account.id)
    assert_response 424
  ensure
    Social::Twitter::Feed.unstub(:following?)
  end

  def test_check_following
    cleanup_twitter_handles(Account.first)
    Twitter::REST::Client.any_instance.stubs(:follow).returns(true)
    Social::Twitter::Feed.stubs(:following?).returns([nil,true])
    follow
    get :check_following, controller_params("screen_name" => @screen_name_to_follow, "id" => @user_twt_account.id )
    assert_response 200
  ensure
    Twitter::REST::Client.any_instance.unstub(:follow)
    Social::Twitter::Feed.unstub(:following?)
  end
end