require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

module Ember
  module Solutions
    class HomeControllerTest < ActionController::TestCase
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper

      def setup
        super
        before_all
      end

      @@before_all_run = false

      def before_all
        return if @@before_all_run

        subscription = @account.subscription
        subscription.state = 'active'
        subscription.save
        @account.reload
        @@before_all_run = true
      end

      def article_params(folder_visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
        category = create_category(portal_id: Account.current.main_portal.id)
        {
          title: 'Test',
          description: 'Test',
          folder_id: create_folder(visibility: folder_visibility, category_id: category.id).id
        }
      end

      def test_summary_without_feature
        get :summary, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Kbase Mint'))
      end

      def test_summary_with_incorrect_credentials
        enable_kbase_mint do
          @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
          get :summary, controller_params(version: 'private')
          assert_response 401
          assert_equal request_error_pattern(:credentials_required).to_json, response.body
          @controller.unstub(:api_current_user)
        end
      end

      def test_summary_without_view_solutions_privilege
        enable_kbase_mint do
          User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
          get :summary, controller_params(version: 'private')
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          User.any_instance.unstub(:privilege?)
        end
      end

      def test_summary_without_access
        enable_kbase_mint do
          user = add_new_user(@account, active: true)
          login_as(user)
          get :summary, controller_params(version: 'private')
          assert_response 403
          match_json(request_error_pattern(:access_denied))
          @admin = get_admin
          login_as(@admin)
        end
      end

      def test_summary_without_portal_id
        enable_kbase_mint do
          get :summary, controller_params(version: 'private')
          assert_response 400
          match_json([bad_request_error_pattern(:portal_id, :datatype_mismatch, code: :missing_field, expected_data_type: String)])
        end
      end

      def test_summary_with_invalid_field
        enable_kbase_mint do
          get :summary, controller_params(version: 'private', portal_id: Account.current.main_portal.id, test: 'Test')
          assert_response 400
          match_json([bad_request_error_pattern('test', :invalid_field)])
        end
      end

      def test_summary_with_invalid_portal_id
        enable_kbase_mint do
          get :summary, controller_params(version: 'private', portal_id: 'Test')
          assert_response 400
          match_json([bad_request_error_pattern(:portal_id, :invalid_portal_id)])
        end
      end

      def test_summary
        enable_kbase_mint do
          portal_id = Account.current.main_portal.id
          create_article(article_params)
          get :summary, controller_params(version: 'private', portal_id: portal_id)
          assert_response 200
          match_json(summary_pattern(portal_id))
        end
      end

      def test_quick_views_without_feature
        portal_id = Account.current.main_portal.id
        get :quick_views, controller_params(version: 'private', portal_id: portal_id)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Kbase Mint'))
      end

      def test_quick_views_without_portal_id
        enable_kbase_mint do
          get :quick_views, controller_params(version: 'private')
          assert_response 400
          match_json([bad_request_error_pattern(:portal_id, :datatype_mismatch, code: :missing_field, expected_data_type: String)])
        end
      end

      def test_quick_views_with_invalid_portal_id
        enable_kbase_mint do
          portal_id = Account.current.portals.last.id
          get :quick_views, controller_params(version: 'private', portal_id: portal_id+1)
          assert_response 400
          match_json([bad_request_error_pattern(:portal_id, :invalid_portal_id)])
        end
      end

      def test_quick_views_portal_with_no_categories
        enable_kbase_mint do
          portal = create_portal
          category_meta = portal.solution_category_meta.where(is_default: false)
          Portal.any_instance.stubs(:solution_category_meta).returns(category_meta)
          get :quick_views, controller_params(version: 'private', portal_id: portal.id)
          Portal.any_instance.unstub(:solution_category_meta)
          assert_response 200
        end
      end

      def test_quick_views_with_user_not_having_view_solutions_privilege
        enable_kbase_mint do
          portal = Account.current.main_portal
          User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
          get :quick_views, controller_params(version: 'private', portal_id: portal.id)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_quick_views_with_valid_params
        enable_kbase_mint do
          solution_test_setup
          create_article(article_params)
          portal = Account.current.main_portal
          get :quick_views, controller_params(version: 'private', portal_id: portal.id)
          assert_response 200
          match_json(quick_views_pattern(portal.id))
        end
      end
    end
  end
end
