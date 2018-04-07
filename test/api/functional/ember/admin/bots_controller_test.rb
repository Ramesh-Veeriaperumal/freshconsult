require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Ember
  module Admin  
    class BotsControllerTest < ActionController::TestCase
      include BotTestHelper
      include SolutionsHelper
      include ProductsHelper
      include AttachmentsTestHelper
      include SolutionBuilderHelper

      BOT_CREATE_HASH = {"content"=>{"_type"=>"bot", "botVrsnHsh"=>"4a6d796657ea459deb15883ceaec4167b556a547", "botHsh"=>"fdc5f5d386fd9a402707bca98f2bb770e2c13b0b", "vrsnNmbr"=>1, "nm"=>"freshdeskbot", "prflPicUrl"=>"https://s3.amazonaws.com/cdn.freshpo.com/data/helpdesk/attachments/development/14/original/beautiful_nature_landscape_05_hd_picture_166223.jpg?1515472982", "intrnlNm"=>"FrankBot", "dscrptn"=>"Include Recommendation, API.AI (remoteResponse) and Agent chat", "actv"=>true, "crtDt"=>"2018-01-13T18:33:57Z"}}
      BOT_UPDATE_HASH = {"status" => "success"} 
      
      def set_up
        super
        before_all
      end

      def wrap_cname(params)
        { bot: params }
      end

      def test_index_without_support_bot_feature
        Account.any_instance.stubs(:bot_onboarded?).returns(false)
        get :index, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
        Account.any_instance.unstub(:bot_onboarded?)
      end

      def test_index_as_not_onboarded_multi_product_account
        enable_bot do
          Account.any_instance.stubs(:bot_onboarded?).returns(false)
          product1 = create_product(portal_url: Faker::Internet.domain_name)
          product2 = create_product(portal_url: Faker::Internet.domain_name)
          get :index, controller_params(version: 'private')
          assert_response 200
          match_json(bot_index_not_onboarded_multiproduct_pattern)
          product1
          product2
          Account.any_instance.unstub(:bot_onboarded?)
        end
      end

      def test_index_as_not_onboarded_multi_product_disabled_account
        enable_bot do
          Account.any_instance.stubs(:bot_onboarded?).returns(false)
          Account.current.products.destroy_all
          get :index, controller_params(version: 'private')
          assert_response 200
          match_json(bot_index_not_onboarded_main_portal_pattern)
          Account.any_instance.unstub(:bot_onboarded?)
        end
      end

      def test_index_onboarded_multi_product_account
        enable_bot do
          Account.any_instance.stubs(:bot_onboarded?).returns(true)
          product1 = create_product(portal_url: Faker::Internet.domain_name)
          product2 = create_product(portal_url: Faker::Internet.domain_name)
          get :index, controller_params(version: 'private')
          assert_response 200
          match_json(bot_index_onboarded_multiproduct_pattern)
          product1
          product2
          Account.any_instance.unstub(:bot_onboarded?)
        end
      end

      def test_index_onboarded_multi_product_disabled_account
        enable_bot do
          Account.any_instance.stubs(:bot_onboarded?).returns(true)
          Account.current.products.destroy_all
          get :index, controller_params(version: 'private')
          assert_response 200
          match_json(bot_index_onboarded_main_portal_pattern)
          Account.any_instance.unstub(:bot_onboarded?)
        end
      end

      def test_new_without_support_bot_feature
        get :new, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_new_with_valid_params
        enable_bot do
          main_portal = @account.main_portal
          category_ids = 3.times.map do
            create_category.id
          end
          main_portal.solution_category_metum_ids = category_ids
          get :new, controller_params(version: 'private', portal_id: main_portal.id)
          assert_response 200
          match_json(bot_new_pattern main_portal)
        end
      end

      def test_new_with_invalid_portal_id
        enable_bot do
          portal = @account.portals.last
          invalid_portal_id = portal.id + 1
          get :new, controller_params(version: 'private', portal_id: invalid_portal_id)
          assert_response 400
          pattern = [:portal_id, :invalid_portal]
          assert_bot_failure pattern
        end
      end

      def test_new_with_bot_already_created_for_the_portal
        enable_bot do
          bot = create_bot({ product: true })
          get :new, controller_params(version: 'private', portal_id: bot.portal_id)
          assert_response 400
          pattern = [:bot_id, "#{bot.id}".to_sym]
          assert_bot_failure pattern
        end
      end

      def test_create_without_mandatory_field
        enable_bot do
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          attachment = create_attachment
          params = create_params(portal)
          post :create, params
          assert_response 400
          pattern = [:avatar, :"It should be a/an key/value pair", {code: "missing_field"}]
          assert_bot_failure pattern
          Account.current.bots = []
          Freshbots::Bot.unstub(:create_bot)
        end
      end


      def test_create_without_support_bot_feature
        portal = create_portal
        params = create_params(portal).merge({ avatar: { is_default: true, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 8}})
        post :create, params
        assert_response 403
        Account.current.bots = []
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_create_with_valid_params_and_default_avatar
        enable_bot do
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          params = create_params(portal).merge({ avatar: { is_default: true, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 8}})
          post :create, params
          assert_response 200
          bot = Bot.last
          match_json(bot_create_pattern bot.id)
          Freshbots::Bot.unstub(:create_bot)
        end
      end

      def test_create_with_valid_params_and_custom_avatar
        enable_bot do
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          attachment = create_attachment 
          params = create_params(portal).merge({ avatar: { is_default: false, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: attachment.id}})
          post :create, params
          assert_response 200
          bot = Bot.last
          match_json(bot_create_pattern bot.id)
          Freshbots::Bot.unstub(:create_bot)
        end
      end

      def test_create_with_invalid_custom_avatar
        enable_bot do
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          attachment = create_attachment 
          invalid_att_id = attachment.id + 1
          params = create_params(portal).merge({ avatar: { is_default: false, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: invalid_att_id}})
          post :create, params
          assert_response 400
          pattern = [:avatar, :invalid_attachment, {code: "invalid_value"}]
          assert_bot_failure pattern
          Account.current.bots = []
          Freshbots::Bot.unstub(:create_bot)
        end
      end

      def test_create_with_bot_already_created_for_the_portal
        enable_bot do
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          bot = create_bot({ product: true })
          params = create_params(bot.portal).merge({ avatar: { is_default: true, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1}})
          post :create, params 
          assert_response 400
          pattern = [:bot_id, "#{bot.id}".to_sym]
          assert_bot_failure pattern
          Freshbots::Bot.unstub(:create_bot)
        end
      end

      def test_show_without_support_bot_feature
        bot = create_bot({ product: true})
        get :show, controller_params(version: 'private', id: bot.id)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_show_with_invalid_bot_id
        enable_bot do
          bot = create_bot({ product: true})
          invalid_bot_id = bot.id + 1
          get :show, controller_params(version: 'private', id: invalid_bot_id)
          assert_response 404
        end
      end

      def test_show_with_valid_params
        enable_bot do
          bot = create_bot({ product: true})
          category_ids = 3.times.map do
            create_category.id
          end
          bot.portal.solution_category_metum_ids = category_ids
          bot.category_ids = category_ids[0...-1]
          get :show, controller_params(version: 'private', id: bot.id)
          assert_response 200
          match_json(show_pattern bot)
        end
      end

      def test_update_without_support_bot_feature
        bot = create_bot({ product: true})
        Freshbots::Bot.stubs(:update_bot).returns(["success", 200])
        put :update, controller_params(version: 'private', id: bot.id, name: "TestBot")
        Freshbots::Bot.unstub(:update_bot)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_update_with_valid_params
        enable_bot do
          Freshbots::Bot.stubs(:update_bot).returns(["success", 200])
          bot = create_bot({ product: true, default_avatar: 1})
          put :update, construct_params( version: 'private', id: bot.id, avatar: { url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: bot.additional_settings[:is_default]} )
          Freshbots::Bot.unstub(:update_bot)
          assert_response 204
        end
      end

      def test_update_with_invalid_bot_id
        enable_bot do
          Freshbots::Bot.stubs(:update_bot).returns(["success", 200])
          bot = create_bot({ product: true})
          invalid_bot_id = bot.id + 1
          put :update, construct_params( version: 'private', id: invalid_bot_id, avatar: { is_default: false, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: bot.additional_settings[:is_default]} )
          Freshbots::Bot.unstub(:update_bot)
          assert_response 404
        end
      end

      def test_update_with_invalid_avatar
        enable_bot do
          Freshbots::Bot.stubs(:update_bot).returns([Freshbots, 200])
          bot = create_bot({ product: true})
          attachment = @account.attachments.last
          invalid_att_id = attachment.id + 1
          put :update, construct_params( version: 'private', id: bot.id, avatar: { is_default: false, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: invalid_att_id} )
          Freshbots::Bot.unstub(:update_bot)
          assert_response 400
          pattern = [:avatar, :invalid_attachment, {code: "invalid_value"}]
          assert_bot_failure pattern
        end
      end

      def test_map_categories_without_support_bot_feature
        put :map_categories, construct_params({ version: 'private', id: 1, category_ids: [1, 2] }, false)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_map_categories_with_incorrect_credentials
        enable_bot do
          @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
          put :map_categories, construct_params({ version: 'private', id: 1, category_ids: [1, 2] }, false)
          assert_response 401
          assert_equal request_error_pattern(:credentials_required).to_json, response.body
          @controller.unstub(:api_current_user)
        end
      end

      def test_map_categories_without_admin_access
        enable_bot do
          user = add_new_user(@account)
          login_as(user)
          put :map_categories, construct_params({ version: 'private', id: 1, category_ids: [1, 2] }, false)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          @admin = get_admin
          login_as(@admin)
        end
      end

      def test_map_categories_with_non_existant_bot
        enable_bot do
          bot = create_bot({product: true})
          put :map_categories, construct_params({ version: 'private', id: 9999, category_ids: [1, 2] }, false)
          assert_response 404
        end
      end

      def test_map_categories_without_category_ids
        enable_bot do
          bot = create_bot({product: true})
          put :map_categories, construct_params({ version: 'private', id: bot.id }, false)
          assert_response 400
          match_json([bad_request_error_pattern('category_ids', :missing_field)])
        end
      end

      def test_map_categories_with_invalid_input_for_category_ids
        enable_bot do
          bot = create_bot({product: true})
          put :map_categories, construct_params({ version: 'private', id: bot.id, category_ids: 1 }, false)
          assert_response 400
          match_json([bad_request_error_pattern('category_ids', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Integer')])
        end
      end

      def test_map_categories_with_category_ids_not_mapped_to_portal
        enable_bot do
          bot = create_bot({product: true})
          put :map_categories, construct_params({ version: 'private', id: bot.id, category_ids: [1,2] }, false)
          assert_response 400
          match_json([bad_request_error_pattern('category_ids', :invalid_category_ids, code: :invalid_value)])
        end
      end

      def test_map_categories
        enable_bot do
          bot = create_bot({product: true})
          category_ids = 3.times.map do
            create_category.id
          end
          bot.portal.solution_category_metum_ids = category_ids
          Ml::Bot.stubs(:update_ml).returns(true)
          put :map_categories, construct_params({ version: 'private', id: bot.id, category_ids: category_ids }, false)
          Ml::Bot.unstub(:update_ml)
          assert_response 204
          assert_equal category_ids, bot.solution_category_metum_ids
        end
      end

      def test_training_completed_without_bot_feature
        bot = create_bot({ product: true})
        post :training_completed, controller_params(version: 'private', id: bot.id)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end   
      
      def test_training_completed_without_access
        enable_bot do
          bot = create_bot({ product: true})
          post :training_completed, controller_params(version: 'private', id: bot.id)
          assert_response 401
          match_json(request_error_pattern(:invalid_credentials))
        end
      end

      def test_training_completed_with_invalid_bot_id
        enable_bot do
          set_auth_header
          bot = create_bot({ product: true})
          post :training_completed, controller_params(version: 'private', id: bot.id)
          assert_response 404
        end
      end

      def test_training_completed
        enable_bot do
          set_auth_header
          bot = create_bot({ product: true})
          bot.training_inprogress!
          post :training_completed, controller_params(version: 'private', id: bot.external_id)
          assert_response 204
          assert bot.training_status.to_i == BotConstants::BOT_STATUS[:training_completed]
        end
      end

      def test_training_completed_with_invalid_state
        enable_bot do
          set_auth_header
          bot = create_bot({ product: true})
          bot.training_completed!
          post :training_completed, controller_params(version: 'private', id: bot.external_id)
          assert_response 409
          match_json(request_error_pattern(:invalid_bot_state))
        end
      end

      def test_clear_status_redis
        enable_bot do
          bot = create_bot({ product: true})
          bot.training_completed!
          post :mark_completed_status_seen, controller_params(version: 'private', id: bot.id)
          assert_response 204
          assert_nil bot.training_status
        end
      end

      def test_clear_status_redis_without_bot_feature
        bot = create_bot({ product: true})
        post :mark_completed_status_seen, controller_params(version: 'private', id: bot.id)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_clear_status_redis_with_invalid_id
        enable_bot do
          bot = create_bot({ product: true})
          post :mark_completed_status_seen, controller_params(version: 'private', id: bot.id+20)
          assert_response 404
        end
      end

      def test_clear_status_redis_with_invalid_state
        enable_bot do
          bot = create_bot({ product: true})
          bot.training_inprogress!
          post :mark_completed_status_seen, controller_params(version: 'private', id: bot.id)
          assert_response 409
          match_json(request_error_pattern(:invalid_bot_state))
        end
      end

      def test_enable_on_portal
        enable_bot do
          bot = create_bot({ product: true})
          bot.enable_in_portal = false
          bot.save
          put :enable_on_portal, construct_params({version: 'private', id: bot.id},{enable_on_portal: true})
          assert_response 204
          assert Bot.find_by_id(bot.id).enable_in_portal == true
        end
      end

      def test_enable_on_portal_with_invalid_bot_id
        enable_bot do
          bot = create_bot({ product: true})
          put :enable_on_portal, construct_params({version: 'private', id: bot.id+20},{enable_on_portal: true})
          assert_response 404
        end
      end

      def test_enable_on_portal_with_invalid_params
        enable_bot do
          bot = create_bot({ product: true})
          put :enable_on_portal, construct_params({version: 'private', id: bot.id},{enable_on_portal: 'true'})
          assert_response 400
          match_json([bad_request_error_pattern('enable_on_portal', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
        end
      end

      def test_enable_on_portal_without_feature
        bot = create_bot({ product: true})
        put :enable_on_portal, construct_params({version: 'private', id: bot.id}, {enable_on_portal: true})
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_enable_on_portal_with_missing_field
        enable_bot do
          bot = create_bot({ product: true})
          put :enable_on_portal, construct_params({version: 'private', id: bot.id},{})
          assert_response 400
          match_json([bad_request_error_pattern('enable_on_portal',:missing_field)])
        end
      end
    end
  end
end
