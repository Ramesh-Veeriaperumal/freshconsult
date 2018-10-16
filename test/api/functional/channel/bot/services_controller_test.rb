require_relative '../../../test_helper'
module Channel
  module Bot
    class ServicesControllerTest < ActionController::TestCase
      include BotTestHelper
      include ProductsHelper
      include JweTestHelper
      include AttachmentsTestHelper

      SUPPORT_BOT = 'frankbot'.freeze

      def setup
        super
        @controller.request.env['HTTP_AUTHORIZATION'] = nil
      end

      def wrap_cname(params)
        { bot: params }
      end

      def test_training_completed_without_bot_feature
        bot = create_bot(product: true)
        post :training_completed, controller_params(version: 'private', id: bot.id)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_training_completed_without_access
        enable_bot do
          bot = create_bot(product: true)
          post :training_completed, controller_params(version: 'private', id: bot.id)
          assert_response 401
          match_json(request_error_pattern(:invalid_credentials))
        end
      end

      def test_training_completed_with_invalid_bot_id
        enable_bot do
          set_jwe_auth_header(SUPPORT_BOT)
          bot = create_bot(product: true)
          post :training_completed, controller_params(version: 'private', id: bot.id)
          assert_response 404
        end
      end

      def test_training_completed_with_invalid_state
        enable_bot do
          set_jwe_auth_header(SUPPORT_BOT)
          bot = create_bot(product: true)
          bot.training_completed!
          post :training_completed, controller_params(version: 'private', id: bot.external_id)
          assert_response 409
          match_json(request_error_pattern(:invalid_bot_state))
        end
      end

      def test_training_completed
        enable_bot do
          set_jwe_auth_header(SUPPORT_BOT)
          bot = create_bot(product: true)
          bot.training_inprogress!
          post :training_completed, controller_params(version: 'private', id: bot.external_id)
          assert_response 204
          assert bot.training_status.to_i == BotConstants::BOT_STATUS[:training_completed]
        end
      end

      def test_training_completed_for_account_with_api_jwt_auth_feature
        enable_bot do
          Account.current.launch(:api_jwt_auth)
          set_jwe_auth_header(SUPPORT_BOT)
          bot = create_bot(product: true)
          bot.training_inprogress!
          post :training_completed, controller_params(version: 'private', id: bot.external_id)
          assert_response 204
          assert bot.training_status.to_i == BotConstants::BOT_STATUS[:training_completed]
          Account.current.rollback(:api_jwt_auth)
        end
      end
    end
  end
end
