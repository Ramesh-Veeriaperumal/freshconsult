require_relative '../../../test_helper'
module Ember
  module Solutions
    class FoldersControllerTest < ActionController::TestCase
      include SolutionsTestHelper
      include SolutionFoldersTestHelper

      def setup
        super
        initial_setup
        @account.reload
      end

      @@initial_setup_run = false

      def initial_setup
        return if @@initial_setup_run
        additional = @account.account_additional_settings
        additional.supported_languages = ['es', 'ru-RU']
        additional.save
        @account.features.enable_multilingual.create
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

      def test_bulk_update_without_anyproperties
        sample_category_meta = get_category_with_folders
        put :bulk_update, construct_params({ version: 'private' }, ids: sample_category_meta.solution_folder_meta.pluck(:id))
        assert_response 400
      end

      private

        def bulk_validation_error_pattern(field, code)
          {
            description: 'Validation failed',
            errors: [
              {
                field: 'properties',
                nested_field: "properties.#{field}",
                message: :string,
                code: code.to_s
              }
            ]
          }
        end
    end
  end
end
