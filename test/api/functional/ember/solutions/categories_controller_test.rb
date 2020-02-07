require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

module Ember
  module Solutions
    class CategoriesControllerTest < ActionController::TestCase
      # We can remove it when we add category controller class in ember namespace
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper

      def setup
        super
        before_all
        @private_api = true
        @account.features.enable_multilingual.create
      end

      @@before_all_run = false

      def before_all
        return if @@before_all_run

        additional = @account.account_additional_settings
        additional.supported_languages = ['es', 'ru-RU']
        additional.save
        @account.reload
        @@before_all_run = true
      end

      def wrap_cname(params)
        { category: params }
      end

      def test_index
        get :index, controller_params(version: 'private')
        assert_response 200
        categories = @account.reload.solution_categories.joins(:solution_category_meta).where('solution_categories.language_id = ?', @account.language_object.id).select { |x| x unless x.parent.is_default }
        pattern = categories.map { |category| solution_category_pattern(category) }
        match_json(pattern)
      end

      def test_index_with_portal_id
        get :index, controller_params(version: 'private', portal_id: @account.main_portal.id)
        assert_response 200
        categories = @account.reload.solution_categories.joins(:solution_category_meta, solution_category_meta: :portal_solution_categories).where('solution_categories.language_id = ? AND portal_solution_categories.portal_id = ?', @account.language_object.id, @account.main_portal.id).order('portal_solution_categories.position').select { |x| x unless x.parent.is_default }
        pattern = categories.map { |category| solution_category_pattern(category) }
        match_json(pattern)
      end

      def test_reorder_without_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(false)
        populate_categories(@account.main_portal)
        portal_solution_categories = @account.main_portal.portal_solution_categories.joins(:solution_category_meta).where('solution_category_meta.is_default' => false)
        put :reorder, construct_params({ version: 'private', id: portal_solution_categories.first.solution_category_meta_id }, position: 1)
        assert_response 403
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_reorder_without_position
        populate_categories(@account.main_portal)
        portal_solution_categories = @account.main_portal.portal_solution_categories.joins(:solution_category_meta).where('solution_category_meta.is_default' => false)
        put :reorder, construct_params(version: 'private', id: portal_solution_categories.first.solution_category_meta_id, portal_id: @account.main_portal.id)
        match_json(validation_error_pattern(bad_request_error_pattern(:position, 'It should be a/an Positive Integer', code: :missing_field)))
      end

      def test_reorder_without_portal_id
        populate_categories(@account.main_portal)
        portal_solution_categories = @account.main_portal.portal_solution_categories.joins(:solution_category_meta).where('solution_category_meta.is_default' => false)
        put :reorder, construct_params({ version: 'private', id: portal_solution_categories.first.solution_category_meta_id }, position: 1)
        assert_response 400
        match_json(validation_error_pattern(bad_request_error_pattern(:portal_id, :invalid_portal_id, code: :invalid_value)))
      end

      def test_reorder
        populate_categories(@account.main_portal)
        portal = @account.main_portal
        portal_solution_categories = @account.main_portal.portal_solution_categories.reorder('portal_solution_categories.position').joins(:solution_category_meta).where('solution_category_meta.is_default' => false)
        old_id_order = portal_solution_categories.pluck(:solution_category_meta_id)
        put :reorder, construct_params({ version: 'private', portal_id: @account.main_portal.id, id: portal_solution_categories.first.solution_category_meta_id }, position: 7)
        assert_response 204
        new_id_order = portal_solution_categories.reload.pluck(:solution_category_meta_id)
        assert old_id_order.slice(1, 6) == new_id_order.slice(0, 6)
        assert old_id_order[0] == new_id_order[6]
        assert old_id_order.slice(7, old_id_order.size) == new_id_order.slice(7, new_id_order.size)
      end

      def test_index_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        get :index, controller_params(version: 'private')
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_index_without_view_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :index, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_index_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        get :index, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_index_with_invalid_field
        get :index, controller_params(version: 'private', test: 'test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_index_with_language_without_multilingual_feature
        @account.features.enable_multilingual.destroy
        get :index, controller_params(version: 'private', language: @account.supported_languages.last)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      end

      def test_index_with_invalid_language
        get :index, controller_params(version: 'private', language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_index_with_primary_language
        get :index, controller_params(version: 'private', language: @account.language)
        assert_response 200
      end

      def test_index_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        create_category(portal_id: Account.current.main_portal.id, lang_codes: languages)
        get :index, controller_params(version: 'private', language: language)
        assert_response 200
      end

      def test_show_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        get :show, controller_params(version: 'private', id: 1)
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_show_without_view_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :show, controller_params(version: 'private', id: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_show_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        get :show, controller_params(version: 'private', id: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_show_for_non_existant_category
        get :show, controller_params(version: 'private', id: 0)
        assert_response 404
      end

      def test_show
        category = create_category(portal_id: Account.current.main_portal.id)
        get :show, controller_params(version: 'private', id: category.id)
        assert_response 200
        match_json(solution_category_pattern(category.primary_category))
      end

      def test_show_with_language_without_multilingual_feature
        @account.features.enable_multilingual.destroy
        get :show, controller_params(version: 'private', id: 0, language: @account.supported_languages.last)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      end

      def test_show_with_invalid_language
        get :show, controller_params(version: 'private', id: 0, language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_show_with_primary_language
        category_meta = create_category(portal_id: Account.current.main_portal.id)
        get :show, controller_params(version: 'private', id: category_meta.id, language: @account.language)
        assert_response 200
        match_json(solution_category_pattern(category_meta.primary_category))
      end

      def test_show_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        category_meta = create_category(portal_id: Account.current.main_portal.id, lang_codes: languages)
        category = category_meta.safe_send("#{language}_category")
        get :show, controller_params(version: 'private', id: category_meta.id, language: language)
        assert_response 200
        match_json(solution_category_pattern(category))
      end

      def test_update_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        put :update, construct_params(version: 'private', id: 1)
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_update_without_manage_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(false)
        put :update, construct_params(version: 'private', id: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        put :update, construct_params(version: 'private', id: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_update_for_non_existant_category
        put :update, construct_params(version: 'private', id: 0)
        assert_response 404
      end

      def test_update_with_invalid_field
        category = create_category(portal_id: Account.current.main_portal.id)
        put :update, construct_params(version: 'private', id: category.id, test: 'test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_update
        category = create_category(portal_id: Account.current.main_portal.id)
        updated_name = 'Updated ' + category.primary_category.name
        put :update, construct_params(version: 'private', id: category.id, name: updated_name)
        assert_response 200
        category.reload
        assert_equal updated_name, category.primary_category.name
        match_json(solution_category_pattern(category.primary_category))
      end

      def test_update_with_language_without_multilingual_feature
        @account.features.enable_multilingual.destroy
        put :update, construct_params(version: 'private', id: 0, language: @account.supported_languages.last)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      end

      def test_update_with_invalid_language
        put :update, construct_params(version: 'private', id: 0, language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_update_with_primary_language
        category = create_category(portal_id: Account.current.main_portal.id)
        updated_name = 'Updated ' + category.primary_category.name
        put :update, construct_params(version: 'private', id: category.id, name: updated_name, language: @account.language)
        assert_response 200
        category.reload
        assert_equal updated_name, category.primary_category.name
        match_json(solution_category_pattern(category.primary_category))
      end

      def test_update_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        category_meta = create_category(portal_id: Account.current.main_portal.id, lang_codes: languages)
        category = category_meta.safe_send("#{language}_category")
        updated_name = 'Updated ' + category.name
        put :update, construct_params(version: 'private', id: category_meta.id, name: updated_name, language: language)
        assert_response 200
        category.reload
        assert_equal updated_name, category.name
        match_json(solution_category_pattern(category))
      end

      def test_create_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        post :create, construct_params(version: 'private')
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_create_without_manage_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(false)
        post :create, construct_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_create_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        post :create, construct_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_create_with_invalid_field
        post :create, construct_params({ version: 'private' }, test: 'test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_create
        post :create, construct_params({ version: 'private' }, name: Faker::Name.name, description: Faker::Lorem.paragraph)
        assert_response 201
        category = @account.solution_category_meta.last
        match_json(solution_category_pattern(category.primary_category))
        assert_equal category.portal_ids, [@account.main_portal.id]
      end

      def test_create_with_language_without_multilingual_feature
        category = create_category(portal_id: Account.current.main_portal.id)
        Account.any_instance.stubs(:multilingual?).returns(false)
        post :create, construct_params({ version: 'private', id: category.id, language: @account.supported_languages.last }, name: Faker::Name.name, description: Faker::Lorem.paragraph)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_create_with_invalid_language
        category = create_category(portal_id: Account.current.main_portal.id)
        post :create, construct_params({ version: 'private', id: category.id, language: 'test' }, name: Faker::Name.name, description: Faker::Lorem.paragraph)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: @account.supported_languages.sort.join(', ')))
      end

      def test_create_with_primary_language
        category = create_category(portal_id: Account.current.main_portal.id)
        post :create, construct_params({ version: 'private', id: category.id, language: @account.language }, name: Faker::Name.name, description: Faker::Lorem.paragraph)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: @account.language, list: @account.supported_languages.sort.join(', ')))
      end

      def test_create_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        category_meta = create_category(portal_id: Account.current.main_portal.id)
        post :create, construct_params({ version: 'private', id: category_meta.id, language: language }, name: Faker::Name.name, description: Faker::Lorem.paragraph)
        assert_response 201
        match_json(solution_category_pattern(category_meta.safe_send("#{language}_category")))
      end

      def test_destroy_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        delete :destroy, controller_params(version: 'private', id: 0)
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_destroy_without_manage_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(false)
        delete :destroy, controller_params(version: 'private', id: 0)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_destroy_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        delete :destroy, controller_params(version: 'private', id: 0)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_destroy_with_language
        delete :destroy, controller_params(version: 'private', id: 0, language: @account.language)
        assert_response 404
      end

      def test_destroy_for_non_existant_category
        put :update, controller_params(version: 'private', id: 0)
        assert_response 404
      end

      def test_destroy
        category_meta = create_category(portal_id: Account.current.main_portal.id)
        delete :destroy, controller_params(version: 'private', id: category_meta.id)
        assert_response 204
      end

      private

        def get_category
          @account.solution_category_meta.where(is_default: false).select(&:children).first
        end

        def populate_categories(portal)
          return if portal.portal_solution_categories.size > 10

          (1..10).each do |index|
            category_meta = Solution::CategoryMeta.new(account_id: @account.id, is_default: false)
            category_meta.save

            category = Solution::Category.new
            category.name = "#{Faker::Name.name} #{index}"
            category.description = 'es cat description'
            category.language_id = Language.find_by_code(@account.language).id
            category.parent_id = category_meta.id
            category.account = @account
            category.save
          end
        end
    end
  end
end
