require_relative '../../../test_helper'
module Ember
  module Discussions
    class TopicsControllerTest < ActionController::TestCase
      include DiscussionsTestHelper

      def setup
        super
        before_all
      end

      @before_all_run = false

      def before_all
        @topic = @account.topics.first || create_test_topic(@account.forums.first, User.current)
        @before_all_run = false
      end

      def wrap_cname(params)
        { topic: params }
      end

      def test_show_without_forums_feature
        disable_forums
        get :show, controller_params(version: 'private', id: @topic.id)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Forums'))
      end

      def test_show_with_incorrect_credentials
        enable_forums do
          @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
          get :show, controller_params(version: 'private', id: @topic.id)
          assert_response 401
          assert_equal request_error_pattern(:credentials_required).to_json, response.body
          @controller.unstub(:api_current_user)
        end
      end

      def test_show_without_privilege
        enable_forums do
          User.any_instance.stubs(:privilege?).with(:view_forums).returns(false)
          get :show, controller_params(version: 'private', id: @topic.id)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_show_with_non_existant_topic
        enable_forums do
          get :show, controller_params(version: 'private', id: 0)
          assert_response 404
        end
      end

      def test_show
        enable_forums do
          get :show, controller_params(version: 'private', id: @topic.id)
          assert_response 200
          match_json(topic_pattern(@topic))
        end
      end

      def test_first_post_without_forums_feature
        disable_forums
        get :first_post, controller_params(version: 'private', id: @topic.id)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Forums'))
      end

      def test_first_post_with_incorrect_credentials
        enable_forums do
          @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
          get :first_post, controller_params(version: 'private', id: @topic.id)
          assert_response 401
          assert_equal request_error_pattern(:credentials_required).to_json, response.body
          @controller.unstub(:api_current_user)
        end
      end

      def test_first_post_without_privilege
        enable_forums do
          User.any_instance.stubs(:privilege?).with(:view_forums).returns(false)
          get :first_post, controller_params(version: 'private', id: @topic.id)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_first_post_with_non_existant_topic
        enable_forums do
          get :first_post, controller_params(version: 'private', id: 0)
          assert_response 404
        end
      end

      def test_first_post
        enable_forums do
          get :first_post, controller_params(version: 'private', id: @topic.id)
          assert_response 200
          match_json(first_post_pattern(@topic))
        end
      end
    end
  end
end
