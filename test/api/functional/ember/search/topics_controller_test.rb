require_relative '../../../test_helper'
['forum_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

module Ember::Search
  class TopicsControllerTest < ActionController::TestCase
    include ForumHelper
    include PrivilegesHelper
    include SearchTestHelper

    def test_results_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      post :results, construct_params(version: 'private', context: 'spotlight', term:  Faker::Lorem.word, limit: 3)
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end

    def test_results_with_valid_params
      topic = create_test_topic(Account.current.forums.first)
      stub_private_search_response([topic]) do
        post :results, construct_params(version: 'private', context: 'spotlight', term:  Faker::Lorem.word, limit: 3)
      end
      assert_response 200
      assert_equal [topic_pattern(topic)].to_json, response.body
    end

    def test_results_with_merge_context
      topic = create_test_topic(Account.current.forums.first)
      stub_private_search_response([topic]) do
        post :results, construct_params(version: 'private', context: 'merge', term:  Faker::Lorem.word, limit: 3)
      end
      assert_response 200
      assert_equal [topic_pattern(topic)].to_json, response.body
    end

    def test_results_without_forums_privilege
      User.any_instance.stubs(:privilege?).with(:view_forums).returns(false)
      post :results, construct_params(version: 'private', context: 'spotlight', term:  Faker::Lorem.word, limit: 3)
      assert_response 403
      User.any_instance.unstub(:privilege?)
    end
  end
end
