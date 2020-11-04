require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require 'webmock/minitest'
WebMock.allow_net_connect!

module Ember
  module Admin  
    class BotFeedbacksControllerTest < ActionController::TestCase
      include ApiBotTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper

      BULK_BOT_FEEDBACK_COUNT = 2

      def setup
        super
        before_all
      end

      @before_all_run = false

      def before_all
        portal_id = @account.main_portal.id
        subscription = @account.subscription
        subscription.state = 'active'
        subscription.save
        @account.reload
        @bot = Account.current.bots.where(portal_id: portal_id).first || create_bot({ product: false, default_avatar: 1})
        @bot.bot_feedbacks.each(&:destroy)
        @bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
        @before_all_run = true
      end

      def wrap_cname(params)
        { bot_feedback: params }
      end

      def test_index_without_bot_feature
        disable_bot do
          get :index, controller_params(version: 'private', id: @bot.id)
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
        end
      end

      def test_index_with_bot_feature
        enable_bot do
          get :index, controller_params(version: 'private', id: @bot.id, start_at: DateTime.now.utc - 6, end_at: DateTime.now.utc + 1)
          assert_response 200
          match_json(bot_feedback_index_pattern(@bot, DateTime.now.utc - 6, DateTime.now.utc + 1))
        end
      end

      def test_index_with_bot_ticket
        enable_bot do
          enable_multiple_user_companies
          helpdesk_ticket = create_ticket_with_requester_and_companies
          bot_feedback = create_bot_feedback_and_bot_ticket(helpdesk_ticket,@bot)

          get :index, controller_params(version: 'private', id: @bot.id, start_at: DateTime.now.utc - 6, end_at: DateTime.now.utc + 1)
          assert_response 200
          match_json(bot_feedback_index_pattern(@bot, DateTime.now.utc - 6, DateTime.now.utc + 1))

          parsed_response = JSON.parse(response.body)

          # with bot_ticket
          feedback_with_bot_ticket = parsed_response.select { |n| n['id'] == bot_feedback.id }[0]
          assert_equal feedback_with_bot_ticket['ticket_id'], helpdesk_ticket.display_id
          assert_equal feedback_with_bot_ticket['requester']['id'], helpdesk_ticket.requester_id

          #without bot_ticket
          feedback_without_bot_ticket = parsed_response.select { |n| n['id'] == @bot_feedback_ids[0] }[0]
          assert_equal feedback_without_bot_ticket['ticket_id'], nil
          assert_equal feedback_without_bot_ticket['requester'], nil
        end
      end

      def test_index_with_invalid_bot
        enable_bot do
          get :index, controller_params(version: 'private', id: 0, start_at: DateTime.now.utc - 6, end_at: DateTime.now.utc + 1)
          assert_response 404
        end
      end

      def test_index_with_no_dates
        enable_bot do
          get :index, controller_params(version: 'private', id: @bot.id)
          match_json([bad_request_error_pattern(:start_at, :invalid_date, code: :missing_field, accepted: 'combined date and time ISO8601'),
                      bad_request_error_pattern(:end_at, :invalid_date, code: :missing_field, accepted: 'combined date and time ISO8601')])
          assert_response 400
        end
      end
    
      def test_index_with_no_start_at
        enable_bot do
          get :index, controller_params(version: 'private', id: @bot.id, end_at: DateTime.now.utc)
          match_json([bad_request_error_pattern(:start_at, :invalid_date, code: :missing_field, accepted: 'combined date and time ISO8601')])
          assert_response 400
        end
      end  

      def test_index_with_no_end_at
        enable_bot do
          get :index, controller_params(version: 'private', id: @bot.id, start_at: DateTime.now.utc)
          match_json([bad_request_error_pattern(:end_at, :invalid_date, code: :missing_field, accepted: 'combined date and time ISO8601')])
          assert_response 400
        end
      end  

      def test_index_with_invalid_start_at
        enable_bot do
          get :index, controller_params(version: 'private', id: @bot.id, start_at: 'test', end_at: DateTime.now.utc)
          match_json([bad_request_error_pattern(:start_at, :invalid_date, accepted: 'combined date and time ISO8601')])
          assert_response 400
        end
      end 

      def test_index_with_invalid_end_at
        enable_bot do
          get :index, controller_params(version: 'private', id: @bot.id, start_at: DateTime.now.utc, end_at: 12345)
          match_json([bad_request_error_pattern(:end_at, :invalid_date, accepted: 'combined date and time ISO8601')])
          assert_response 400
        end
      end 

      def test_index_with_lesser_end_at
        enable_bot do
          get :index, controller_params(version: 'private', id: @bot.id, start_at: DateTime.now.utc, end_at: DateTime.now.utc - 1)
          match_json([bad_request_error_pattern(:end_at, :unanswered_time_period_invalid)])
          assert_response 400
        end
      end

      def test_index_with_no_suggestions
        enable_bot do
          create_bot_feedback(@bot, category: 2, useful: 1)
          get :index, controller_params(version: 'private', id: @bot.id, useful: 1, start_at: DateTime.now.utc - 6, end_at: DateTime.now.utc + 1)
          match_json(bot_feedback_index_pattern(@bot, DateTime.now.utc - 6, DateTime.now.utc + 1, 1))
          assert_response 200
        end
      end

      def test_index_with_suggestions_but_not_useful
        enable_bot do
          create_bot_feedback(@bot, category: 2, useful: 3)
          get :index, controller_params(version: 'private', id: @bot.id, useful: 3, start_at: DateTime.now.utc - 6, end_at: DateTime.now.utc + 1)
          match_json(bot_feedback_index_pattern(@bot, DateTime.now.utc - 6, DateTime.now.utc + 1, 3))
          assert_response 200
        end
      end

      def test_index_invalid_useful
        enable_bot do
          get :index, controller_params(version: 'private', id: @bot.id, useful: 4, start_at: DateTime.now.utc - 6, end_at: DateTime.now.utc + 1)
          assert_response 400
          match_json([bad_request_error_pattern(:useful, :not_included, list: '1,2,3')])
        end
      end

      def test_index_only_unanswered
        enable_bot do
          unanswered_count = @bot.bot_feedbacks.where(category: 2).count
          create_bot_feedback(@bot, category: 1, useful: 2) # create answered feedback
          get :index, controller_params(version: 'private', id: @bot.id, start_at: DateTime.now.utc - 6, end_at: DateTime.now.utc + 1)
          assert_response 200
          assert_equal JSON.parse(response.body).count, unanswered_count
        end
      end

      def test_index_without_manage_freddy_answers_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false).at_most_once
          get :index, controller_params(version: 'private', id: @bot.id, start_at: DateTime.now.utc - 6, end_at: DateTime.now.utc + 1)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_index
        enable_bot do
          create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          get :index, controller_params(version: 'private', id: @bot.id, start_at: DateTime.now.utc - 1, end_at: DateTime.now.utc)
          match_json(bot_feedback_index_pattern(@bot, DateTime.now.utc - 1, DateTime.now.utc))
          assert_response 200
        end
      end

      def test_bulk_delete_without_params
        enable_bot do
          put :bulk_delete, construct_params(version: 'private',id: @bot.id)
          assert_response 400
          match_json([bad_request_error_pattern('ids', :missing_field)])
        end
      end

      def test_bulk_delete_with_invalid_ids
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          invalid_ids = [bot_feedback_ids.last + 20]
          ids_to_delete = [*bot_feedback_ids,*invalid_ids]
          put :bulk_delete, construct_params({version: 'private', id: @bot.id}, ids: ids_to_delete)
          failures = {}
          invalid_ids.each { |id| failures[id] = { id: :"is invalid" } }
          match_json(partial_success_response_pattern(bot_feedback_ids, failures))
          assert_response 202
        end
      end

      def test_bulk_delete_with_errors_in_deletion
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          ids_to_delete = bot_feedback_ids
          @controller.stubs(:destroy_item).returns(false)
          put :bulk_delete, construct_params({ version: 'private', id: @bot.id}, ids: ids_to_delete)
          failures = {}
          ids_to_delete.each { |id| failures[id] = { id: :unable_to_perform } }
          match_json(partial_success_response_pattern([], failures))
          assert_response 202
        end
      end

      def test_bulk_delete_with_valid_ids
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          put :bulk_delete, construct_params({ version: 'private', id: @bot.id}, ids: bot_feedback_ids)
          assert_response 204
          bot_feedback_ids.each do |bot_feedback_id|
            assert Bot::Feedback.find_by_id(bot_feedback_id).state == BotFeedbackConstants::FEEDBACK_STATE_KEYS_BY_TOKEN[:deleted]
          end
        end
      end

      def test_bulk_delete_without_feature
        bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
        put :bulk_delete, construct_params({ version: 'private', id: @bot.id}, ids: bot_feedback_ids)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_bulk_delete_without_manage_freddy_answers_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          put :bulk_delete, construct_params({ version: 'private', id: @bot.id}, ids: bot_feedback_ids)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_bulk_delete_without_publish_solution_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(true)
          User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          put :bulk_delete, construct_params({ version: 'private', id: @bot.id}, ids: bot_feedback_ids)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_bulk_delete_without_publish_solution_and_freddy_answers_privileges
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          put :bulk_delete, construct_params({ version: 'private', id: @bot.id}, ids: bot_feedback_ids)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_bulk_delete_with_invalid_state
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          invalid_bot_feedback = @account.bot_feedbacks.find_by_id(bot_feedback_ids.last)
          invalid_bot_feedback.state = BotFeedbackConstants::FEEDBACK_STATE_KEYS_BY_TOKEN[:deleted]
          invalid_bot_feedback.save
          put :bulk_delete, construct_params({version: 'private', id: @bot.id}, ids: bot_feedback_ids)
          failures = {}
          failures[invalid_bot_feedback.id] = { id: :"invalid_bot_feedback_state" }
          match_json(partial_success_response_pattern(bot_feedback_ids-Array(invalid_bot_feedback.id), failures))
          assert_response 202
        end
      end

      def test_bulk_map_article
        enable_bot do
          Account.any_instance.stubs(:multilingual?).returns(:true)
          article = create_article(article_params)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id])
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id,ids: bot_feedback_ids})
          assert_response 204
        end
      end

      def test_bulk_map_article_without_feature
        article = create_article(article_params)
        bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
        Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id])
        put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id,ids: bot_feedback_ids})
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_bulk_map_article_without_publish_solution_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(true)
          User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
          article = create_article(article_params)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id])
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id,ids: bot_feedback_ids})
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_bulk_map_article_without_manage_freddy_answers_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          article = create_article(article_params)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id])
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id,ids: bot_feedback_ids})
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_bulk_delete_without_publish_solution_and_manage_freddy_answers_privileges
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          article = create_article(article_params)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id])
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id,ids: bot_feedback_ids})
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_bulk_map_article_without_article_id
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {ids: bot_feedback_ids})
          assert_response 400
          match_json([bad_request_error_pattern('article_id', :missing_field)])
        end
      end

      def test_bulk_map_article_with_invalid_article_id
        enable_bot do
          article = create_article(article_params)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id])
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id + 20,ids: bot_feedback_ids})
          assert_response 400
          match_json([bad_request_error_pattern('article_id', :invalid_article)])
        end
      end

      def test_bulk_map_article_with_different_folder_visibility
        enable_bot do
          Account.any_instance.stubs(:multilingual?).returns(:true)
          article = create_article(article_params(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:agents]))
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id]) 
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id,ids: bot_feedback_ids})
          assert_response 400
          match_json([bad_request_error_pattern('article_id', :invalid_bot_article)])
        end
      end

      def test_bulk_map_article_with_already_mapped_state
        enable_bot do
          Account.any_instance.stubs(:multilingual?).returns(:true)
          article = create_article(article_params)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id])
          invalid_bot_feedback = @account.bot_feedbacks.find_by_id(bot_feedback_ids.last)
          invalid_bot_feedback.state = BotFeedbackConstants::FEEDBACK_STATE_KEYS_BY_TOKEN[:mapped]
          invalid_bot_feedback.save
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id, ids: bot_feedback_ids})
          failures = {}
          failures[invalid_bot_feedback.id] = { id: :"invalid_bot_feedback_state" }
          match_json(partial_success_response_pattern(bot_feedback_ids-Array(invalid_bot_feedback.id), failures))
          assert_response 202
        end
      end

      def test_bulk_map_article_with_invalid_bot_feedback
        enable_bot do
          Account.any_instance.stubs(:multilingual?).returns(:true)
          article = create_article(article_params)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id])
          invalid_ids = [bot_feedback_ids.last + 20]
          ids_to_map = [*bot_feedback_ids,*invalid_ids]
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id, ids: ids_to_map})
          failures = {}
          invalid_ids.each { |id| failures[id] = { id: :"is invalid" } }
          match_json(partial_success_response_pattern(bot_feedback_ids, failures))
          assert_response 202
        end
      end

      def test_bulk_map_article_with_errors_in_map
        enable_bot do
          Account.any_instance.stubs(:multilingual?).returns(:true)
          article = create_article(article_params)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id])
          @controller.stubs(:map_article).returns(false)
          ids_to_map = bot_feedback_ids
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id, ids: ids_to_map})
          failures = {}
          bot_feedback_ids.each { |id| failures[id] = { id: :"unable_to_perform" } }
          match_json(partial_success_response_pattern([], failures))
          assert_response 202
        end
      end

      def test_bulk_map_article_with_extra_params
        enable_bot do
          article = create_article(article_params)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          Bot.any_instance.stubs(:category_ids).returns([Solution::CategoryMeta.last.id])
          put :bulk_map_article, construct_params({version: 'private', id: @bot.id}, {article_id: article.id,ids: bot_feedback_ids,test: 'test'})
          assert_response 400
          match_json([bad_request_error_pattern('test', :invalid_field)])
        end
      end

      def test_create_article_without_support_bot_feature
        bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
        post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids))
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_create_article_with_incorrect_credentials
        enable_bot do
          @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids))
          assert_response 401
          assert_equal request_error_pattern(:credentials_required).to_json, response.body
          @controller.unstub(:api_current_user)
        end
      end

      def test_create_article_without_manage_freddy_answers_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids))
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_create_article_without_publish_solution_privilege
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(true)
          User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids))
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_create_article_without_publish_solution_and_manage_freddy_answers_privileges
        enable_bot do
          User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_freddy_answers).returns(false)
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids))
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_create_article_with_non_existant_bot
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params({ version: 'private', id: 999999 }, article_params.merge(ids: bot_feedback_ids))
          assert_response 404
        end
      end

      def test_create_article_without_mandatory_params
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params(version: 'private', id: @bot.id)
          assert_response 400
          match_json([bad_request_error_pattern('title', :missing_field),
                      bad_request_error_pattern('description', :missing_field),
                      bad_request_error_pattern('folder_id', :missing_field),
                      bad_request_error_pattern('ids', :missing_field)])
        end
      end

      def test_create_article_with_mandatory_params_invalid
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params({ version: 'private', id: @bot.id }, invalid_article_params.merge(ids: 'Test'))
          assert_response 400
          match_json([bad_request_error_pattern(:title, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                      bad_request_error_pattern(:description, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                      bad_request_error_pattern(:folder_id, :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                      bad_request_error_pattern(:ids, :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
        end
      end

      def test_create_article_with_invalid_field
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids, test: 'Test'))
          assert_response 400
          match_json([bad_request_error_pattern('test', :invalid_field)])
        end
      end

      def test_create_article_with_non_existant_folder
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge!(folder_id: 9999, ids: bot_feedback_ids))
          assert_response 400
          match_json([bad_request_error_pattern('folder_id', :invalid_folder)])
        end
      end

      def test_create_article_with_folder_not_visible_to_bot
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:agents]).merge(ids: bot_feedback_ids))
          assert_response 400
          match_json([bad_request_error_pattern('folder_id', :invalid_folder_visibility)])
        end
      end

      def test_create_article_for_mapped_bot_feedback
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          mapped_bot_feedback = create_bot_feedback(@bot.id, state: BotFeedbackConstants::FEEDBACK_STATE_KEYS_BY_TOKEN[:mapped])
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: (bot_feedback_ids + [mapped_bot_feedback.id])))
          (failures ||= {})[mapped_bot_feedback.id] = { id: :invalid_bot_feedback_state }
          match_json(partial_success_response_pattern((bot_feedback_ids - [mapped_bot_feedback.id]), failures))
          assert_response 202
        end
      end

      def test_create_article_for_invalid_bot_feedback
        enable_bot do
          valid_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          invalid_feedback_ids = [9999]
          bot_feedback_ids = valid_feedback_ids + invalid_feedback_ids
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids))
          failures = {}
          invalid_feedback_ids.each { |id| failures[id] = { id: :'is invalid' } }
          match_json(partial_success_response_pattern(valid_feedback_ids, failures))
          assert_response 202
        end
      end

      def test_create_article_for_all_invalid_bot_feedbacks
        enable_bot do
          bot_feedback_ids = [9999, 6666]
          articles_count = @account.solution_article_meta.size
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids))
          failures = {}
          bot_feedback_ids.each { |id| failures[id] = { id: :'is invalid' } }
          match_json(partial_success_response_pattern([], failures))
          assert_equal @account.solution_article_meta.size, articles_count
          assert_response 202
        end
      end

      def test_create_article_with_failure_in_mapping
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          @controller.stubs(:map_article).returns(false)
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids))
          failures = {}
          bot_feedback_ids.each { |id| failures[id] = { id: :unable_to_perform } }
          match_json(partial_success_response_pattern([], failures))
          assert_response 202
        end
      end

      def test_create_article
        enable_bot do
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          articles_count = @account.solution_article_meta.size
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids))
          assert_response 204
          assert_equal @account.solution_article_meta.size, (articles_count + 1)
        end
      end

      def test_create_article_failure_in_save
        enable_bot do
          @controller.stubs(:primary_article_hash).returns({})
          bot_feedback_ids = create_n_bot_feedbacks(@bot.id, BULK_BOT_FEEDBACK_COUNT)
          post :create_article, construct_params({ version: 'private', id: @bot.id }, article_params.merge(ids: bot_feedback_ids))
          @controller.unstub(:primary_article_hash)
          assert_response 400
        end
      end

      def test_chat_history
        enable_bot do
          Account.current.launch(FeatureConstants::BOT_CHAT_HISTORY)
          bot_feedback = Account.current.bot_feedbacks.find_by_id(@bot_feedback_ids.first)
          stub_request(:get,%r{^https://api.intfreshbots.com/api/v1/customer.*?$}).to_return(body: chat_history_hash(bot_feedback.query_id).to_json, status: 200)
          get :chat_history, controller_params(version: 'private', id: @bot_feedback_ids.first)
          assert_response 200
          match_json(chat_history_pattern(bot_feedback))
          Account.current.rollback(FeatureConstants::BOT_CHAT_HISTORY)
        end
      end

      def test_chat_history_without_launchparty
        enable_bot do
          get :chat_history, controller_params(version: 'private', id: @bot_feedback_ids.first)
          assert_response 403
        end
      end

      def test_chat_history_with_exception
        enable_bot do
          Account.current.launch(:bot_chat_history)
          Freshbots::Bot.stubs(:chat_messages).raises('ChatHistoryApiException')
          get :chat_history, controller_params(version: 'private', id: @bot_feedback_ids.first)
          assert_response 500
          Freshbots::Bot.unstub(:chat_messages)
          Account.current.rollback(:bot_chat_history)
        end
      end

      def test_chat_history_for_end_of_message_meta
        enable_bot do
          Account.current.launch(:bot_chat_history)
          bot_feedback = Account.current.bot_feedbacks.find_by_id(@bot_feedback_ids.first)
          stub_request(:get,%r{^https://api.intfreshbots.com/api/v1/customer.*?$}).to_return(body: chat_history_hash(bot_feedback.query_id).to_json, status: 200)
          get :chat_history, controller_params(version: 'private', id: @bot_feedback_ids.first)
          assert_response 200
          assert_equal response.api_meta[:end_of_message], true
          match_json(chat_history_pattern(bot_feedback))
          Account.current.rollback(:bot_chat_history)
        end
      end

      def test_chat_history_with_invalid_bot_feedback
        enable_bot do
          Account.current.launch(:bot_chat_history)
          get :chat_history, controller_params(version: 'private', id: @bot_feedback_ids.last+20)
          assert_response 404
          Account.current.rollback(:bot_chat_history)
        end
      end

      def test_chat_history_with_invalid_field
        enable_bot do
          Account.current.launch(:bot_chat_history)
          get :chat_history, controller_params(version: 'private', id: @bot_feedback_ids.first, test: 'abc')
          assert_response 500
          Account.current.rollback(:bot_chat_history)
        end
      end

      def test_chat_history_with_invalid_direction_param
        enable_bot do
          Account.current.launch(:bot_chat_history)
          get :chat_history, controller_params(version: 'private', id: @bot_feedback_ids.first, direction: 'abc')
          assert_response 400
          match_json([bad_request_error_pattern('direction', :not_included, code: :invalid_value, list: BotFeedbackConstants::CHAT_HISTORY_DIRECTIONS.join(','))])
          Account.current.rollback(:bot_chat_history)
        end
      end

      def test_create_feedback_check_bot_type
        enable_bot do
          bot_feedback = @bot.bot_feedbacks.build(bot_feedback_params(@bot, category: 2, useful: 1))
          bot_feedback.save
          assert_equal bot_feedback.bot.external_id, @bot.external_id
        end
      end

    end
  end
end
