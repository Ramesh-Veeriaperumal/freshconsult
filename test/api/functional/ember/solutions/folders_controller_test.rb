require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

module Ember
  module Solutions
    class FoldersControllerTest < ActionController::TestCase
      include SolutionsTestHelper
      include SolutionFoldersTestHelper
      include SolutionBuilderHelper
      include SolutionsHelper
      include ContactSegmentsTestHelper
      include CompanySegmentsTestHelper
      include AttachmentsTestHelper
      include SolutionsPlatformsTestHelper

      def setup
        super
        initial_setup
        @account.reload
        @account.features.enable_multilingual.create
        @account.add_feature(:segments)
      end

      @@initial_setup_run = false

      def initial_setup
        return if @@initial_setup_run
        additional = @account.account_additional_settings
        additional.supported_languages = ['es', 'ru-RU']
        additional.save
        @account.add_feature(:auto_article_order)
        @@initial_setup_run = true
      end

      def test_index
        get :index, controller_params(version: 'private')
        categories = get_category_folders
        assert_response 200
        pattern = []
        categories.each do |category|
          category.solution_folders.where('language_id = ?', @account.language_object.id).each do |f|
            pattern << solution_folder_pattern_private(f)
          end
        end
        match_json(pattern)
      end

      def test_index_language
        language = @account.supported_languages.first
        get :index, controller_params(version: 'private', language: language)
        assert_response 200
        categories = get_category_folders
        pattern = []
        categories.each do |category|
          category.solution_folders.where('language_id = ?', Language.find_by_code(language).id).each do |f|
            pattern << solution_folder_pattern_private(f)
          end
        end
        match_json(pattern)
      end

      def test_index_invalid_language
        get :index, controller_params(version: 'private', language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_index_category_folders
        sample_category_meta = get_category_with_folders
        get :category_folders, controller_params(version: 'private', id: sample_category_meta.id)
        assert_response 200
        assert_equal response.api_root_key, :folders
        result_pattern = []
        sample_category_meta.solution_folders.where('language_id = ?', @account.language_object.id).each do |f|
          result_pattern << solution_folder_pattern_private(f)
        end
        match_json(result_pattern.ordered!)
      end

      def test_create_folder
        category_meta = get_category
        post :create, construct_params({ id: category_meta.id, version: 'private' }, name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1)
        assert_response 201
        result = parse_response(@response.body)
        match_json(solution_folder_pattern_private(Solution::Folder.last))
      end

      def test_create_folder_with_article_order_without_feature
        Account.any_instance.stubs(:auto_article_order_enabled?).returns(false)
        category_meta = get_category
        post :create, construct_params({ id: category_meta.id, version: 'private' }, name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], article_order: Solution::Constants::ARTICLE_ORDER_KEYS_TOKEN[:custom])
        assert_response 400
        match_json([bad_request_error_pattern(:article_order, :require_feature_for_attribute, code: :inaccessible_field, feature: :auto_article_order, attribute: :article_order)])
      ensure
        Account.any_instance.unstub(:auto_article_order_enabled?)
      end

      def test_create_folder_with_article_order_with_feature
        category_meta = get_category
        post :create, construct_params({ id: category_meta.id, version: 'private' }, name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], article_order: Solution::Constants::ARTICLE_ORDER_KEYS_TOKEN[:custom])
        assert_response 201
        result = parse_response(@response.body)
        match_json(solution_folder_pattern_private(Solution::Folder.last))
      end

      def test_show_folder
        sample_folder = get_folder
        get :show, controller_params(version: 'private', id: sample_folder.parent_id)
        match_json(solution_folder_pattern_private(sample_folder))
        assert_response 200
      end

      def test_update_folder
        name = Faker::Name.name
        visibility = 4
        sample_folder = get_folder
        old_description = sample_folder.description
        old_name = sample_folder.name
        params_hash = { visibility: visibility, company_ids: [@account.customer_ids.last], article_order: 2 }
        put :update, construct_params({ id: sample_folder.parent_id, version: 'private' }, params_hash)
        assert_response 200
        match_json(solution_folder_pattern_private(sample_folder.reload))
        assert sample_folder.reload.name == old_name
        assert sample_folder.reload.description == old_description
        assert sample_folder.reload.solution_folder_meta.visibility == visibility
        assert sample_folder.reload.solution_folder_meta.customer_ids == [@account.customer_ids.last]
      end

      def test_update_folder_name_and_category
        category_meta = get_category
        name = category_meta.solution_folder_meta.first.name
        new_folder = create_folder(name: name)
        params_hash = { name: "#{Faker::Name.name} #{Time.now.utc}", category_id: category_meta.id }
        put :update, construct_params({ id: Solution::FolderMeta.last.id, version: 'private' }, params_hash)
        assert_response 200
      end

      def test_update_category_with_duplicate_name
        category_meta = get_category
        name = category_meta.solution_folder_meta.first.name
        new_folder = create_folder(name: name)
        params_hash = { name: name, category_id: category_meta.id }
        put :update, construct_params({ id: Solution::FolderMeta.last.id, version: 'private' }, params_hash)
        assert_response 409
        match_json(validation_error_pattern(:name, :duplicate_value))
      end

      def test_bulk_update
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 1 })
        assert_response 204
        sample_category_meta.reload
        assert sample_category_meta.solution_folder_meta.all? { |folder_meta| folder_meta.visibility == 1 }
      end

      def test_bulk_update_without_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(false)
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 1 })
        assert_response 403
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_with_invalid_category
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { category_id: 10_101_010_101 })
        assert_response 400
        match_json(bulk_validation_error_pattern(:category_id, :invalid_category_id))
      end

      def test_bulk_update_with_invalid_visibility
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 1010 })
        assert_response 400
        match_json(bulk_validation_error_pattern(:visibility, :invalid_value))
      end

      def test_bulk_update_visibility_without_companies
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 4 })
        assert_response 400
        match_json(bulk_validation_error_pattern(:company_ids, :company_ids_not_present))
      end

      def test_bulk_update_invalid_visibility_with_companies
        company = get_company
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 3, company_ids: [company.id] })
        assert_response 400
        match_json(bulk_validation_error_pattern(:company_ids, :company_ids_not_allowed))
      end

      def test_bulk_update_with_visibility_with_companies
        sample_category_meta = get_category_with_folders
        company = get_company
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 4, company_ids: [company.id] })
        assert_response 204
        sample_category_meta.reload.solution_folder_meta.each { |folder| assert folder.customer_folders.pluck(:customer_id).include?(company.id) }
      end

      def test_bulk_update_with_visibility_with_invalid_companies
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 4, company_ids: [10_101_010] })
        assert_response 400
        match_json(bulk_validation_error_pattern(:company_ids, :invalid_company_ids))
      end

      # bulk update contact segments
      def test_bulk_update_visibility_contact_segments_without_contact_segment_ids
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 6 })
        assert_response 400
        match_json(bulk_validation_error_pattern(:contact_segment_ids, :contact_segment_ids_not_present))
      end

      def test_bulk_update_invalid_visibility_with_contact_segment_ids
        segment = create_contact_segment
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 3, contact_segment_ids: [segment.id] })
        assert_response 400
        match_json(bulk_validation_error_pattern(:contact_segment_ids, :contact_segment_ids_not_allowed))
      end

      def test_bulk_update_with_visibility_contact_segments_with_contact_segment_ids
        sample_category_meta = get_category_with_folders
        segment = create_contact_segment
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 6, contact_segment_ids: [segment.id] })
        assert_response 204
        sample_category_meta.reload.solution_folder_meta.each { |folder| assert folder.folder_visibility_mapping.where(mappable_type: 'ContactFilter').pluck(:mappable_id).include?(segment.id) }
      end

      def test_bulk_update_with_visibility_contact_segments_with_invalid_contact_segment_ids
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 6, contact_segment_ids: [10_101_010] })
        assert_response 400
        match_json(bulk_validation_error_pattern(:contact_segment_ids, :invalid_contact_segment_ids))
      end

      # bulk update company segments
      def test_bulk_update_visibility_company_segments_without_company_segment_ids
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 7 })
        assert_response 400
        match_json(bulk_validation_error_pattern(:company_segment_ids, :company_segment_ids_not_present))
      end

      def test_bulk_update_invalid_visibility_with_company_segment_ids
        segment = create_company_segment
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 3, company_segment_ids: [segment.id] })
        assert_response 400
        match_json(bulk_validation_error_pattern(:company_segment_ids, :company_segment_ids_not_allowed))
      end

      def test_bulk_update_with_visibility_company_segments_with_company_segment_ids
        sample_category_meta = get_category_with_folders
        segment = create_company_segment
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 7, company_segment_ids: [segment.id] })
        assert_response 204
        sample_category_meta.reload.solution_folder_meta.each { |folder| assert folder.folder_visibility_mapping.where(mappable_type: 'CompanyFilter').pluck(:mappable_id).include?(segment.id) }
      end

      def test_bulk_update_with_visibility_company_segments_with_invalid_company_segment_ids
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id), properties: { visibility: 7, company_segment_ids: [10_101_010] })
        assert_response 400
        match_json(bulk_validation_error_pattern(:company_segment_ids, :invalid_company_segment_ids))
      end

      def test_bulk_update_without_anyproperties
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id))
        assert_response 400
      end

      def test_reorder_without_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(false)
        sample_category_meta = get_category_with_folders
        put :reorder, construct_params({ version: 'private' }, id: sample_category_meta.solution_folder_meta.first.id, position: sample_category_meta.solution_folder_meta.size)
        assert_response 403
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_reorder_without_position
        sample_category_meta = get_category_with_folders
        put :reorder, construct_params(version: 'private', id: sample_category_meta.solution_folder_meta.first.id)
        match_json(validation_error_pattern(:position, :missing_field))
      end

      def test_reorder
        sample_category_meta = get_category_with_folders
        populate_folders(sample_category_meta)
        old_id_order = sample_category_meta.solution_folder_meta.pluck(:id)
        put :reorder, construct_params({ version: 'private', id: sample_category_meta.solution_folder_meta.first.id }, position: 10)
        assert_response 204
        new_id_order = sample_category_meta.reload.solution_folder_meta.pluck(:id)
        assert old_id_order.slice(1, 9) == new_id_order.slice(0, 9)
        assert old_id_order[0] == new_id_order[9]
        assert old_id_order.slice(10, old_id_order.size) == new_id_order.slice(10, new_id_order.size)
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
        create_solution_folder(languages)
        get :index, controller_params(version: 'private', language: language)
        assert_response 200
      end

      def test_category_folders_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        get :category_folders, controller_params(version: 'private', id: 0)
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_category_folders_without_view_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :category_folders, controller_params(version: 'private', id: 0)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_category_folders_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        get :category_folders, controller_params(version: 'private', id: 0)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_category_folders_with_language_without_multilingual_feature
        @account.features.enable_multilingual.destroy
        get :category_folders, controller_params(version: 'private', id: 0, language: @account.supported_languages.last)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      end

      def test_category_folders_with_invalid_language
        get :category_folders, controller_params(version: 'private', id: 0, language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_category_folders_with_primary_language
        category = create_category(portal_id: Account.current.main_portal.id)
        get :category_folders, controller_params(version: 'private', id: category.id, language: @account.language)
        assert_response 200
      end

      def test_category_folders_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        category = create_category(portal_id: Account.current.main_portal.id, lang_codes: languages)
        get :category_folders, controller_params(version: 'private', id: category.id, language: language)
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

      def test_show_for_non_existant_folder
        get :show, controller_params(version: 'private', id: 0)
        assert_response 404
      end

      def test_show
        folder = create_solution_folder
        get :show, controller_params(version: 'private', id: folder.id)
        assert_response 200
        match_json(solution_folder_pattern_private(folder.primary_folder))
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
        folder_meta = create_solution_folder
        get :show, controller_params(version: 'private', id: folder_meta.id, language: @account.language)
        assert_response 200
        match_json(solution_folder_pattern_private(folder_meta.primary_folder))
      end

      def test_show_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        folder_meta = create_solution_folder(languages)
        folder = folder_meta.safe_send("#{language}_folder")
        get :show, controller_params(version: 'private', id: folder_meta.id, language: language)
        assert_response 200
        match_json(solution_folder_pattern_private(folder))
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

      def test_update_for_non_existant_folder
        put :update, construct_params(version: 'private', id: 0)
        assert_response 404
      end

      def test_update_with_invalid_field
        folder = create_solution_folder
        put :update, construct_params(version: 'private', id: folder.id, test: 'test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_update
        folder = create_solution_folder
        updated_name = 'Updated ' + folder.primary_folder.name
        put :update, construct_params(version: 'private', id: folder.id, name: updated_name)
        assert_response 200
        folder.reload
        assert_equal updated_name, folder.primary_folder.name
        match_json(solution_folder_pattern_private(folder.primary_folder))
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
        folder = create_solution_folder
        updated_name = 'Updated ' + folder.primary_folder.name
        put :update, construct_params(version: 'private', id: folder.id, name: updated_name, language: @account.language)
        assert_response 200
        folder.reload
        assert_equal updated_name, folder.primary_folder.name
        match_json(solution_folder_pattern_private(folder.primary_folder))
      end

      def test_update_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        folder_meta = create_solution_folder(languages)
        folder = folder_meta.safe_send("#{language}_folder")
        updated_name = 'Updated ' + folder.name
        put :update, construct_params(version: 'private', id: folder_meta.id, name: updated_name, language: language)
        assert_response 200
        folder.reload
        assert_equal updated_name, folder.name
        match_json(solution_folder_pattern_private(folder))
      end

      def test_create_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        post :create, construct_params(version: 'private', id: 0)
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_create_without_manage_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(false)
        post :create, construct_params(version: 'private', id: 0)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_create_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        post :create, construct_params(version: 'private', id: 0)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_create_with_invalid_field
        category = create_category(portal_id: Account.current.main_portal.id)
        post :create, construct_params({ version: 'private', id: category.id }, test: 'test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_create
        category = create_category(portal_id: Account.current.main_portal.id)
        post :create, construct_params({ version: 'private', id: category.id }, name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
        assert_response 201
        folder = @account.solution_folder_meta.last
        match_json(solution_folder_pattern_private(folder.primary_folder))
      end

      def test_create_with_language_without_multilingual_feature
        folder = create_solution_folder
        Account.any_instance.stubs(:multilingual?).returns(false)
        post :create, construct_params({ version: 'private', id: folder.id, language: @account.supported_languages.last }, name: Faker::Name.name, description: Faker::Lorem.paragraph)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_create_with_invalid_language
        folder = create_solution_folder
        post :create, construct_params({ version: 'private', id: folder.id, language: 'test' }, name: Faker::Name.name, description: Faker::Lorem.paragraph)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: @account.supported_languages.sort.join(', ')))
      end

      def test_create_with_primary_language
        folder = create_solution_folder
        post :create, construct_params({ version: 'private', id: folder.id, language: @account.language }, name: Faker::Name.name, description: Faker::Lorem.paragraph)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: @account.language, list: @account.supported_languages.sort.join(', ')))
      end

      def test_create_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        category = create_category(portal_id: Account.current.main_portal.id, lang_codes: languages)
        folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id)

        post :create, construct_params({ version: 'private', id: folder_meta.id, language: language }, name: Faker::Name.name, description: Faker::Lorem.paragraph)
        assert_response 201
        match_json(solution_folder_pattern_private(folder_meta.safe_send("#{language}_folder")))
      end

      def test_create_folder_with_visibility_anyone_and_platforms
        enable_omni_bundle do
          category_meta = get_category
          post :create, construct_params({ version: 'private', id: category_meta.id }, name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1, platforms: { ios: true, web: false, android: true })
          assert_response 201
          result = parse_response(@response.body)
          match_json(solution_folder_pattern_private(Solution::Folder.where(parent_id: result['id']).first))
        end
      end

      def test_destroy_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        delete :destroy, controller_params(version: 'private', id: 0)
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_create_folder_with_folder_icon_with_omni_enabled
        enable_omni_bundle do
          file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
          category_meta = get_category
          icon = create_attachment(content: file, attachable_type: 'Image Upload').id
          post :create, construct_params(version: 'private', id: category_meta.id, name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1, icon: icon)
          assert_response 201
          result = parse_response(@response.body)
          assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
          match_json(solution_folder_pattern_private(Solution::Folder.where(parent_id: result['id']).first))
        end
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

      def test_destroy_for_non_existant_folder
        put :update, controller_params(version: 'private', id: 0)
        assert_response 404
      end

      def test_destroy
        folder_meta = create_solution_folder
        delete :destroy, controller_params(version: 'private', id: folder_meta.id)
        assert_response 204
      end

      private

        def populate_folders(category_meta)
          return if category_meta.solution_folder_meta.size > 10

          (1..10).each do |index|
            @folder_meta = Solution::FolderMeta.new
            @folder_meta.visibility = 1
            @folder_meta.solution_category_meta = category_meta
            @folder_meta.account = @account
            @folder_meta.save

            @folder = Solution::Folder.new
            @folder.name = "#{Faker::Name.name} #{index}"
            @folder.description = "test description #{index}"
            @folder.account = @account
            @folder.parent_id = @folder_meta.id
            @folder.language_id = Language.find_by_code(@account.language).id
            @folder.save
          end
        end

        def validation_error_pattern(field, code)
          {
            description: 'Validation failed',
            errors: [
              {
                field: field.to_s,
                message: :string,
                code: code.to_s
              }
            ]
          }
        end

        def create_solution_folder(lang_codes = nil)
          category = create_category(portal_id: Account.current.main_portal.id, lang_codes: lang_codes)
          create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id, lang_codes: lang_codes)
        end
    end
  end
end
