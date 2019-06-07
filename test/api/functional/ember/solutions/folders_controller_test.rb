require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

module Ember
  module Solutions
    class FoldersControllerTest < ActionController::TestCase
      include SolutionsTestHelper
      include SolutionFoldersTestHelper
      include SolutionBuilderHelper
      include SolutionsHelper

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
    end
  end
end
