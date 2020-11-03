require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Ember
  module Admin
    class BotsControllerTest < ActionController::TestCase
      include ApiBotTestHelper
      include SolutionsHelper
      include ProductsHelper
      include AttachmentsTestHelper
      include SolutionBuilderHelper
      include JweTestHelper

      BOT_CREATE_HASH = {"content"=>{"_type"=>"bot", "botVrsnHsh"=>"4a6d796657ea459deb15883ceaec4167b556a547", "botHsh"=>"fdc5f5d386fd9a402707bca98f2bb770e2c13b0b", "vrsnNmbr"=>1, "nm"=>"freshdeskbot", "prflPicUrl"=>"https://s3.amazonaws.com/cdn.freshpo.com/data/helpdesk/attachments/development/14/original/beautiful_nature_landscape_05_hd_picture_166223.jpg?1515472982", "intrnlNm"=>"FrankBot", "dscrptn"=>"Include Recommendation, API.AI (remoteResponse) and Agent chat", "actv"=>true, "crtDt"=>"2018-01-13T18:33:57Z"}}
      BOT_UPDATE_HASH = {"status" => "success"} 
      SUPPORT_BOT = 'frankbot'.freeze

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

      def test_index_without_bot_privileges #neither manage_bots nor view_bots
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          get :index, controller_params(version: 'private')
          User.any_instance.unstub(:privilege?)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
        end
      end

      def test_index_without_view_bots_with_manage_bots_privilege
        enable_bot do
          Account.any_instance.stubs(:bot_onboarded?).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(true)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          product1 = create_product(portal_url: Faker::Internet.domain_name)
          product2 = create_product(portal_url: Faker::Internet.domain_name)
          get :index, controller_params(version: 'private')
          assert_response 200
          User.any_instance.unstub(:privilege?)
          Account.any_instance.unstub(:bot_onboarded?)
        end
      end

      def test_index_without_manage_bots_with_view_bots_rivilege
        enable_bot do
          Account.any_instance.stubs(:bot_onboarded?).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(true)
          product1 = create_product(portal_url: Faker::Internet.domain_name)
          product2 = create_product(portal_url: Faker::Internet.domain_name)
          get :index, controller_params(version: 'private')
          assert_response 200
          User.any_instance.unstub(:privilege?)
          Account.any_instance.unstub(:bot_onboarded?)
        end
      end

      def test_index_as_not_onboarded_multi_product_account
        enable_bot do
          Account.any_instance.stubs(:bot_onboarded?).returns(false)
          product1 = create_product(portal_url: Faker::Internet.domain_name)
          product2 = create_product(portal_url: Faker::Internet.domain_name)
          get :index, controller_params(version: 'private')
          assert_response 200
          match_json(bot_index_not_onboarded_multiproduct_pattern)
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

      def test_new_without_manage_bots_with_view_bots_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(true)
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
          main_portal = @account.main_portal
          category_ids = 3.times.map do
            create_category.id
          end
          get :new, controller_params(version: 'private', portal_id: main_portal.id)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_new_without_view_bots_with_manage_bots_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(true)
          main_portal = @account.main_portal
          category_ids = 3.times.map do
            create_category.id
          end
          main_portal.solution_category_metum_ids = category_ids
          get :new, controller_params(version: 'private', portal_id: main_portal.id)
          assert_response 200
          User.any_instance.unstub(:privilege?)
        end
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
          get :new, controller_params(version: 'private', portal_id: "0")
          assert_response 400
          pattern = [:portal_id, :invalid_portal_id]
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
          match_json([bad_request_error_pattern('avatar', :missing_avatar)])
          Account.current.bots = []
          Freshbots::Bot.unstub(:create_bot)
        end
      end


      def test_create_without_support_bot_feature
        portal = create_portal
        params = create_params(portal).merge({ avatar: { is_default: true, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1 }})
        post :create, params
        assert_response 403
        Account.current.bots = []
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_create_without_manage_bots_with_view_bots_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(true)
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          params = create_params(portal).merge({ avatar: { is_default: true, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1 }})
          post :create, params
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_create_without_view_bot_with_manage_bots_privilege
        enable_bot do
          stub_request(:post, %r{^https://system42-serv-dev.staging.freddyproject.com.*?$}).to_return(body: { 'success': true }.to_json, headers: { 'Content-Type' => 'application/json' }, status: 200)
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(true)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          params = create_params(portal).merge(avatar: { is_default: true, url: 'https://s3.amazonaws.com/cdn.freshpo.com', avatar_id: 1 })
          post :create, params
          assert_response 200
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_create_bot_exception_system42
        enable_bot do
          stub_request(:post, %r{^https://system42-serv-dev.staging.freddyproject.com.*?$}).to_raise(StandardError)
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(true)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          params = create_params(portal).merge({ avatar: { is_default: true, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1 }})
          post :create, params
          assert_response 200
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_create_with_valid_params_and_default_avatar
        enable_bot do
          stub_request(:post, %r{^https://system42-serv-dev.staging.freddyproject.com.*?$}).to_return(body: { 'success': true }.to_json, headers: { 'Content-Type' => 'application/json' }, status: 200)
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          params = create_params(portal).merge({ avatar: { is_default: true, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1 }})
          post :create, params
          assert_response 200
          bot = Bot.last
          match_json(bot_create_pattern bot.id)
          Freshbots::Bot.unstub(:create_bot)
        end
      end

      def test_create_with_negative_default_avatar_id
        enable_bot do
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          params = create_params(portal).merge({ avatar: { is_default: true, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: -1 }})
          post :create, params
          assert_response 400
          match_json([bad_request_error_pattern_with_nested_field(:avatar, :avatar_id, :datatype_mismatch, code: :invalid_value, expected_data_type: 'Positive Integer')])
          Account.current.bots = []
          Freshbots::Bot.unstub(:create_bot)
        end
      end

      def test_create_with_invalid_default_avatar_id
        enable_bot do
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          params = create_params(portal).merge({ avatar: { is_default: true, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: BotConstants::DEFAULT_AVATAR_COUNT + 1 }})
          post :create, params
          assert_response 400
          match_json([bad_request_error_pattern(:avatar, :invalid_default_avatar)])
          Account.current.bots = []
          Freshbots::Bot.unstub(:create_bot)
        end
      end

      def test_create_with_xss_params
        enable_bot do
          stub_request(:post, %r{^https://system42-serv-dev.staging.freddyproject.com.*?$}).to_return(body: { 'success': true }.to_json, headers: { 'Content-Type' => 'application/json' }, status: 200)
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          params = xss_params(portal).merge({ avatar: { is_default: true, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1 }})
          post :create, params
          assert_response 200
          bot = Bot.last
          assert_equal bot.name, 'alert(5)'
          assert_equal bot.template_data[:header], 'alert(5)'
          Freshbots::Bot.unstub(:create_bot)
        end
      end

      def test_create_with_valid_params_and_custom_avatar
        enable_bot do
          stub_request(:post, %r{^https://system42-serv-dev.staging.freddyproject.com.*?$}).to_return(body: { 'success': true }.to_json, headers: { 'Content-Type' => 'application/json' }, status: 200)
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

      def test_create_with_invalid_avatar_params
        enable_bot do
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          params = create_params(portal).merge({ avatar: { url: "https://s3.amazonaws.com/cdn.freshpo.com" }})
          post :create, params
          assert_response 400
          match_json([bad_request_error_pattern_with_nested_field(:avatar, :avatar_id, :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer')])
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

      def test_create_with_bot_api_failure
        enable_bot do
          Freshbots::Bot.stubs(:create_bot).returns([{}, 500])
          portal = create_portal
          attachment = create_attachment 
          params = create_params(portal).merge({ avatar: { is_default: false, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: attachment.id}})
          post :create, params
          assert_response 500
          Freshbots::Bot.unstub(:create_bot)
        end
      end

      def test_create_with_failure_in_save
        enable_bot do
          @controller.stubs(:save_bot).returns(true)
          Bot.any_instance.stubs(:save).returns(false)
          Freshbots::Bot.stubs(:create_bot).returns([BOT_CREATE_HASH, 201])
          portal = create_portal
          attachment = create_attachment 
          params = create_params(portal).merge({ avatar: { is_default: false, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: attachment.id}})
          post :create, params
          Freshbots::Bot.unstub(:create_bot)
          Bot.any_instance.unstub(:save)
          @controller.unstub(:save_bot)
          assert_response 500
        end
      end

      def test_show_without_support_bot_feature
        bot = create_bot({ product: true})
        get :show, controller_params(version: 'private', id: bot.id)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_show_without_manage_bot_with_view_bots_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(true)
          bot = create_bot({ product: true})
          category_ids = 3.times.map do
            create_category.id
          end
          bot.portal.solution_category_metum_ids = category_ids
          bot.portal.save
          bot.category_ids = category_ids[0...-1]
          get :show, controller_params(version: 'private', id: bot.id)
          assert_response 200
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_show_without_view_bot_with_manage_bot_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(true)
          bot = create_bot({ product: true})
          category_ids = 3.times.map do
            create_category.id
          end
          bot.portal.solution_category_metum_ids = category_ids
          bot.portal.save
          bot.category_ids = category_ids[0...-1]
          get :show, controller_params(version: 'private', id: bot.id)
          assert_response 200
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_show_neither_manage_bot_nor_view_bot_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
          bot = create_bot({ product: true})
          category_ids = 3.times.map do
            create_category.id
          end
          bot.portal.solution_category_metum_ids = category_ids
          bot.category_ids = category_ids[0...-1]
          get :show, controller_params(version: 'private', id: bot.id)
          assert_response 403
          User.any_instance.unstub(:privilege?)
          match_json(request_error_pattern(:access_denied))
        end
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
          bot.portal.save
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

      def test_update_without_manage_bots_with_view_bots_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(true)
          Freshbots::Bot.stubs(:update_bot).returns(["success", 200])
          bot = create_bot({ product: true, default_avatar: 1})
          put :update, construct_params( version: 'private', id: bot.id, avatar: { url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1 } )
          Freshbots::Bot.unstub(:update_bot)
          User.any_instance.unstub(:privilege?)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
        end
      end

      def test_update_without_view_bots_with_manage_bots_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(true)
          Freshbots::Bot.stubs(:update_bot).returns(["success", 200])
          bot = create_bot({ product: true, default_avatar: 1})
          put :update, construct_params( version: 'private', id: bot.id, avatar: { url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1 } )
          Freshbots::Bot.unstub(:update_bot)
          User.any_instance.unstub(:privilege?)
          assert_response 204
        end
      end

      def test_update_with_valid_params
        enable_bot do
          Freshbots::Bot.stubs(:update_bot).returns(["success", 200])
          bot = create_bot({ product: true, default_avatar: 1})
          put :update, construct_params( version: 'private', id: bot.id, avatar: { url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1 } )
          Freshbots::Bot.unstub(:update_bot)
          assert_response 204
        end
      end

      def test_update_with_xss_params
        enable_bot do
          Freshbots::Bot.stubs(:update_bot).returns(["success", 200])
          bot = create_bot({ product: true, default_avatar: 1})
          put :update, construct_params(version: 'private', id: bot.id, name: '<script>alert(5)</script>', header: '<script>alert(5)</script>')
          Freshbots::Bot.unstub(:update_bot)
          assert_response 204
          bot.reload
          assert_equal bot.name, 'alert(5)'
          assert_equal bot.template_data[:header], 'alert(5)'
        end
      end

      def test_update_with_invalid_bot_id
        enable_bot do
          Freshbots::Bot.stubs(:update_bot).returns(["success", 200])
          bot = create_bot({ product: true})
          invalid_bot_id = bot.id + 1
          put :update, construct_params( version: 'private', id: invalid_bot_id, avatar: { is_default: false, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1 } )
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

      def test_update_with_invalid_avatar_params
        enable_bot do
          Freshbots::Bot.stubs(:update_bot).returns([Freshbots, 200])
          bot = create_bot({ product: true})
          put :update, construct_params( version: 'private', id: bot.id, avatar: { url: "https://s3.amazonaws.com/cdn.freshpo.com" } )
          Freshbots::Bot.unstub(:update_bot)
          assert_response 400
          match_json([bad_request_error_pattern_with_nested_field(:avatar, :avatar_id, :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer')])
        end
      end

      def test_update_with_bot_api_failure
        enable_bot do
          Freshbots::Bot.stubs(:update_bot).returns(["failure", 500])
          bot = create_bot({ product: true, default_avatar: 1})
          put :update, construct_params( version: 'private', id: bot.id, avatar: { url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: 1 } )
          Freshbots::Bot.unstub(:update_bot)
          assert_response 500
        end
      end

      def test_update_with_valid_params_and_custom_avatar
        enable_bot do
          Freshbots::Bot.stubs(:update_bot).returns(["success", 200])
          bot = create_bot({ product: true, default_avatar: 1 })
          attachment = create_attachment
          put :update, construct_params( version: 'private', id: bot.id, avatar: { is_default: false, url: "https://s3.amazonaws.com/cdn.freshpo.com", avatar_id: attachment.id } )
          Freshbots::Bot.unstub(:update_bot)
          assert_response 204
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

      def test_map_categories_without_manage_bot_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
          put :map_categories, construct_params({ version: 'private', id: 1, category_ids: [1, 2] }, false)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_map_categories_with_non_existant_bot
        enable_bot do
          bot = create_bot(product: true)
          put :map_categories, construct_params({ version: 'private', id: 9999, category_ids: [1, 2] }, false)
          assert_response 404
        end
      end

      def test_map_categories_without_category_ids
        enable_bot do
          bot = create_bot(product: true)
          put :map_categories, construct_params({ version: 'private', id: bot.id }, false)
          assert_response 400
          match_json([bad_request_error_pattern('category_ids', :missing_field)])
        end
      end

      def test_map_categories_with_invalid_input_for_category_ids
        enable_bot do
          bot = create_bot(product: true)
          put :map_categories, construct_params({ version: 'private', id: bot.id, category_ids: 1 }, false)
          assert_response 400
          match_json([bad_request_error_pattern('category_ids', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Integer')])
        end
      end

      def test_map_categories_with_category_ids_not_mapped_to_portal
        enable_bot do
          bot = create_bot(product: true)
          put :map_categories, construct_params({ version: 'private', id: bot.id, category_ids: [1, 2] }, false)
          assert_response 400
          match_json([bad_request_error_pattern('category_ids', :invalid_category_ids, code: :invalid_value)])
        end
      end

      def test_map_categories_with_ml_api_failure
        enable_bot do
          bot = create_bot(product: true)
          category_ids = 3.times.map do
            create_category.id
          end
          bot.portal.solution_category_metum_ids = category_ids
          bot.portal.save
          Ml::Bot.stubs(:update_ml).returns(false)
          put :map_categories, construct_params({ version: 'private', id: bot.id, category_ids: category_ids }, false)
          Ml::Bot.unstub(:update_ml)
          assert_response 503
        end
      end

      def test_map_categories_with_exception
        enable_bot do
          bot = create_bot(product: true)
          bot.training_not_started!
          Bot.any_instance.stubs(:training_completed!).raises(RuntimeError)
          category_ids = 3.times.map do
            create_category.id
          end
          bot.portal.solution_category_metum_ids = category_ids
          bot.portal.save
          Ml::Bot.stubs(:update_ml).returns(true)
          put :map_categories, construct_params({ version: 'private', id: bot.id, category_ids: category_ids }, false)
          Ml::Bot.unstub(:update_ml)
          Bot.any_instance.unstub(:training_inprogress!)
          assert_response 500
        end
      end

      def test_map_categories
        enable_bot do
          bot = create_bot(product: true)
          category_ids = 3.times.map do
            create_category.id
          end
          bot.portal.solution_category_metum_ids = category_ids
          bot.portal.save
          Ml::Bot.stubs(:update_ml).returns(true)
          put :map_categories, construct_params({ version: 'private', id: bot.id, category_ids: category_ids }, false)
          Ml::Bot.unstub(:update_ml)
          assert_response 204
          assert_equal category_ids, bot.solution_category_metum_ids
        end
      end      

      def test_map_categories_ml_api_stub
        enable_bot do
          bot = create_bot(product: true)
          category_ids = Array.new(3) do
            create_category.id
          end
          bot.portal.solution_category_metum_ids = category_ids
          bot.portal.save
          stub_request(:put, %r{^https://system42-serv-dev.staging.freddyproject.com.*?$}).to_return(body: { 'success': true }.to_json, headers: { 'Content-Type' => 'application/json' }, status: 200)
          put :map_categories, construct_params({ version: 'private', id: bot.id, category_ids: category_ids }, false)
          assert_response 204
          assert_equal category_ids, bot.solution_category_metum_ids
        end
      end

      def test_map_categories_ml_api_stub_exception_system42
        enable_bot do
          bot = create_bot(product: true)
          category_ids = Array.new(3) do
            create_category.id
          end
          bot.portal.solution_category_metum_ids = category_ids
          bot.portal.save
          stub_request(:put, %r{^https://system42-serv-dev.staging.freddyproject.com.*?$}).to_raise(StandardError)
          put :map_categories, construct_params({ version: 'private', id: bot.id, category_ids: category_ids }, false)
          assert_response 503
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

      def test_clear_status_without_manage_bot_privilege
        enable_bot do
          bot = create_bot({ product: true})
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
          post :mark_completed_status_seen, controller_params(version: 'private', id: bot.id)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
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

      def test_enable_on_portal_without_manage_bot_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
          bot = create_bot({ product: true})
          put :enable_on_portal, construct_params({ version: 'private', id: bot.id }, { enable_on_portal: true })
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
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

      def test_email_channel
        enable_bot do
          enable_bot_email_channel do
            bot = create_bot({ product: true })
            bot.enable_in_portal = false
            bot.save
            put :update, construct_params({ version: 'private', id: bot.id }, { email_channel: true })
            assert_response 204
            bot.reload
            assert bot.email_channel == true
          end
        end
      end

      def test_email_channel_without_manage_bot_privilege
        enable_bot do
          enable_bot_email_channel do
            User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
            bot = create_bot({ product: true })
            put :update, construct_params({ version: 'private', id: bot.id }, { email_channel: true })
            assert_response 403
            match_json(request_error_pattern(:access_denied))
            User.any_instance.unstub(:privilege?)
          end
        end
      end

      def test_email_channel_with_invalid_bot_id
        enable_bot do
          enable_bot_email_channel do
            bot = create_bot({ product: true })
            put :update, construct_params({ version: 'private', id: 0 }, { email_channel: true })
            assert_response 404
          end
        end
      end

      def test_email_channel_with_invalid_params
        enable_bot do
          enable_bot_email_channel do
            bot = create_bot({ product: true })
            put :update, construct_params({ version: 'private', id: bot.id }, { email_channel: 'true' })
            assert_response 400
            match_json([bad_request_error_pattern('email_channel', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
          end
        end
      end

      def test_email_channel_without_feature
        bot = create_bot({ product: true })
        put :update, construct_params({ version: 'private', id: bot.id }, { email_channel: true })
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_email_channel_without_email_channel_feature
        enable_bot do
          bot = create_bot({ product: true })
          put :update, construct_params({ version: 'private', id: bot.id}, { email_channel: true })
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'bot_email_channel'))
        end
      end

      def test_email_channel_with_missing_field
        enable_bot do
          enable_bot_email_channel do
            bot = create_bot({ product: true})
            put :update, construct_params({ version: 'private', id: bot.id }, {})
            assert_response 400
            match_json(request_error_pattern(:missing_params))
          end
        end
      end

      def test_bot_folders
        enable_bot do
          bot = create_bot({ product: true})
          category = create_category
          bot.portal.solution_category_metum_ids = [category.id]
          bot.category_ids = [category.id]
          create_folder(category_meta_id: category.id)
          get :bot_folders, controller_params(version: 'private', id: bot.id)
          assert_response 200
        end
      end

      def test_bot_folders_without_support_bot_feature
        bot = create_bot({ product: true})
        disable_bot do
          get :bot_folders, controller_params(version: 'private', id: bot.id)
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
        end
      end

      def test_bot_folders_with_invalid_bot
        enable_bot do
          bot = create_bot({ product: true})
          get :bot_folders, controller_params(version: 'private', id: 0)
          assert_response 404
        end
      end

      def test_bot_folders_without_access
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false).at_most_once
          bot = create_bot({ product: true})
          get :bot_folders, controller_params(version: 'private', id: bot.id)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_create_bot_folder
        enable_bot do
          bot = create_bot({ product: true})
          category = create_category
          bot.portal.solution_category_metum_ids = [category.id]
          bot.portal.save
          bot.category_ids = [category.id]
          params = { name: Faker::Name.name, visibility: 1, category_id: category.id }
          post :create_bot_folder, construct_params(params.merge(version: 'private' , id: bot.id), false)
          assert_response 200
          folder = Solution::FolderMeta.last
          match_json({id: folder.id, visibility: folder.visibility, name: folder.primary_folder.name})
        end
      end

      def test_create_bot_folder_without_support_bot_feature
        bot = create_bot({ product: true})
        disable_bot do
          category = create_category
          bot.portal.solution_category_metum_ids = [category.id]
          bot.category_ids = [category.id]
          params = { name: Faker::Name.name, visibility: 1, category_id: category.id }
          post :create_bot_folder, construct_params(params.merge(version: 'private' , id: bot.id), false)
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
        end
      end

      def test_create_bot_folder_without_visibility
        enable_bot do
          bot = create_bot({ product: true})
          category = create_category
          bot.portal.solution_category_metum_ids = [category.id]
          bot.category_ids = [category.id]
          bot.reload
          params = { name: Faker::Name.name, category_id: category.id }
          post :create_bot_folder, construct_params(params.merge(version: 'private' , id: bot.id), false)
          assert_response 400
        end
      end

      def test_create_bot_folder_without_access
        enable_bot do
          bot = create_bot({ product: true})
          category = create_category
          bot.portal.solution_category_metum_ids = [category.id]
          bot.category_ids = [category.id]
          User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(false).at_most_once
          params = { name: Faker::Name.name, visibility: 1, category_id: category.id }
          post :create_bot_folder, construct_params(params.merge(version: 'private' , id: bot.id), false)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_create_bot_folder_with_invalid_bot
        enable_bot do
          bot = create_bot({ product: true})
          category = create_category
          bot.portal.solution_category_metum_ids = [category.id]
          bot.category_ids = [category.id]
          params = { name: Faker::Name.name, visibility: 1, category_id: category.id }
          post :create_bot_folder, construct_params(params.merge(version: 'private' , id: 0), false)
          assert_response 404
        end
      end

      def test_create_bot_folder_with_same_name
        enable_bot do
          bot = create_bot({ product: true})
          folder = create_folder
          bot.portal.solution_category_metum_ids = [folder.solution_category_meta.id]
          bot.portal.save
          bot.category_ids = [folder.solution_category_meta.id]
          params = { name: folder.name, visibility: 1, category_id: folder.solution_category_meta.id }
          post :create_bot_folder, construct_params(params.merge(version: 'private' , id: bot.id), false)
          assert_response 409
        end
      end

      def test_create_bot_folder_with_invalid_category
        enable_bot do
          bot = create_bot({ product: true})
          params = { name: Faker::Name.name, visibility: 1, category_id: 0 }
          post :create_bot_folder, construct_params(params.merge(version: 'private' , id: bot.id), false)
          assert_response 400
        end
      end

      def test_analytics_without_support_bot_feature
        get :analytics, controller_params(version: 'private', id: 1, start_date: '2018-02-01', end_date: '2018-03-01')
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_analytics_with_incorrect_credentials
        enable_bot do
          @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
          get :analytics, controller_params(version: 'private', id: 1, start_date: '2018-02-01', end_date: '2018-03-01')
          assert_response 401
          assert_equal request_error_pattern(:credentials_required).to_json, response.body
          @controller.unstub(:api_current_user)
        end
      end

      def test_analytics_without_access
        enable_bot do
          user = add_new_user(@account, active: true)
          login_as(user)
          get :analytics, controller_params(version: 'private', id: 1, start_date: '2018-02-01', end_date: '2018-03-01')
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          @admin = get_admin
          login_as(@admin)
        end
      end

      def test_analytics_with_non_existant_bot
        enable_bot do
          get :analytics, controller_params(version: 'private', id: 9999, start_date: '2018-02-01', end_date: '2018-03-01')
          assert_response 404
        end
      end

      def test_analytics_without_start_date_and_end_date
        enable_bot do
          bot = create_bot(product: true)
          get :analytics, controller_params(version: 'private', id: 1)
          assert_response 400
          match_json([bad_request_error_pattern('start_date', :missing_field),
                      bad_request_error_pattern('end_date', :missing_field)])
        end
      end

      def test_analytics_with_invalid_input_for_start_date_and_end_date
        enable_bot do
          bot = create_bot(product: true)
          get :analytics, controller_params(version: 'private', id: 1, start_date: 1, end_date: 1)
          assert_response 400
          match_json([bad_request_error_pattern('start_date', :invalid_date, accepted: 'combined date and time ISO8601'),
                      bad_request_error_pattern('end_date', :invalid_date, accepted: 'combined date and time ISO8601')])
        end
      end

      def test_analytics_with_end_date_less_than_start_date
        enable_bot do
          bot = create_bot(product: true)
          get :analytics, controller_params(version: 'private', id: 1, start_date: '2018-03-01', end_date: '2018-02-01')
          assert_response 400
          match_json([bad_request_error_pattern('end_date', :analytics_time_period_invalid)])
        end
      end

      def test_analytics
        enable_bot do
          Freshbots::Bot.stubs(:analytics).returns([bot_analytics_hash, 200])
          bot = create_bot(product: true)
          get :analytics, controller_params(version: 'private', id: 1, start_date: '2018-02-01', end_date: '2018-02-02')
          assert_response 200
          assert_equal analytics_response_pattern, response.body
        end
      end

      def test_analytics_with_bot_api_failure
        enable_bot do
          Freshbots::Bot.stubs(:analytics).returns([{}, 500])
          bot = create_bot(product: true)
          get :analytics, controller_params(version: 'private', id: 1, start_date: '2018-02-01', end_date: '2018-02-02')
          assert_response 503
        end
      end

      def test_remove_analytics_mock_data
        enable_bot do
          bot = create_bot(product: true)
          put :remove_analytics_mock_data, construct_params(version: 'private', id: bot.id)
          bot.reload
          assert_response 204
          assert_equal nil, bot.additional_settings[:analytics_mock_data]
        end
      end

      def test_remove_analytics_mock_data_with_failure_in_save
        enable_bot do
          bot = create_bot(product: true)
          Bot.any_instance.stubs(:save).returns(false)
          put :remove_analytics_mock_data, construct_params(version: 'private', id: bot.id)
          Bot.any_instance.unstub(:save)
          assert_response 500
        end
      end

      def test_remove_analytics_mock_data_with_incorrect_credentials
        enable_bot do
          @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
          bot = create_bot(product: true)
          put :remove_analytics_mock_data, construct_params(version: 'private', id: bot.id)
          assert_response 401
          assert_equal request_error_pattern(:credentials_required).to_json, response.body
          @controller.unstub(:api_current_user)
        end
      end

      def test_remove_analytics_mock_data_without_view_reports_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:view_reports).returns(false)
          bot = create_bot(product: true)
          put :remove_analytics_mock_data, construct_params(version: 'private', id: bot.id)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_remove_analytics_mock_data_with_invalid_bot_id
        enable_bot do
          put :remove_analytics_mock_data, construct_params(version: 'private', id: 0)
          assert_response 404
        end
      end

      def test_remove_analytics_mock_data_without_support_bot_feature
        bot = create_bot(product: true)
        put :remove_analytics_mock_data, construct_params(version: 'private', id: bot.id)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_remove_analytics_mock_data_for_bot_without_analytics_mock_data
        enable_bot do
          bot = create_bot(product: true)
          bot.additional_settings.delete(:analytics_mock_data)
          bot.save
          put :remove_analytics_mock_data, construct_params(version: 'private', id: bot.id)
          assert_response 400
          match_json([bad_request_error_pattern('id', :not_mock_data)])
        end
      end

      def test_remove_analytics_mock_data_with_invalid_field
        enable_bot do
          bot = create_bot(product: true)
          put :remove_analytics_mock_data, construct_params(version: 'private', id: bot.id, test: 'test')
          assert_response 400
          match_json([bad_request_error_pattern('test', :invalid_field)])
        end
      end
    end
  end
end
