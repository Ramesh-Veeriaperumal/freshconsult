require_relative '../../test_helper'
['contact_segments_test_helper.rb', 'company_segments_test_helper.rb'].each { |file| require "#{Rails.root}/test/lib/helpers/#{file}" }
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module ApiSolutions
  class FoldersControllerTest < ActionController::TestCase
    include SolutionsTestHelper
    include SolutionFoldersTestHelper
    include SolutionsHelper
    include SolutionBuilderHelper
    include ContactSegmentsTestHelper
    include CompanySegmentsTestHelper
    include CoreSolutionsTestHelper

    def setup
      super
      @account.features.enable_multilingual.create
      @account.add_feature(:segments)
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run
      additional = @account.account_additional_settings
      additional.supported_languages = ["es","ru-RU"]
      additional.save
      @account.add_feature(:multi_language)
      @account.reload
      @@initial_setup_run = true
    end

    def test_show_folder
      sample_folder = get_folder
      get :show, controller_params(id: sample_folder.parent_id)
      match_json(solution_folder_pattern(sample_folder))
      assert_response 200
    end

    def test_show_unavailalbe_folder
      get :show, controller_params(id: 99999)
      assert_response :missing
    end

    def test_show_folder_with_unavailable_translation
      language_code = @account.supported_languages.first
      sample_folder = get_folder_without_translation_with_translated_category(language_code)
      get :show, controller_params(id: sample_folder.parent_id, language: language_code)
      assert_response :missing
    end

    def test_show_folder_with_language_query_param
      sample_folder = get_folder
      get :show, controller_params(id: sample_folder.parent_id, language: @account.language)
      match_json(solution_folder_pattern(sample_folder))
      assert_response 200
    end

    def test_show_folder_with_invalid_language_query_param
      sample_folder = get_folder
      get :show, controller_params(id: sample_folder.parent_id, language: 'adadfs')
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: 'adadfs', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
    end

    # Feature Check
    def test_show_folder_with_language_query_param_without_multilingual_feature
      @account.features.enable_multilingual.destroy
      sample_folder = get_folder
      get :show, controller_params(id: sample_folder.parent_id, language: @account.supported_languages.last)
      match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      assert_response 404
    end

    # Create Folder
    def test_create_folder
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1})
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.last))
    end

    def test_create_folder_without_description
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: nil, visibility: 1})
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.last))
    end

    def test_create_folder_without_name_and_visibility
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, description: Faker::Lorem.paragraph)
      assert_response 400
      match_json([bad_request_error_pattern('name', :datatype_mismatch, code: :missing_field, expected_data_type: String),
        bad_request_error_pattern('visibility', :missing_field)])
    end


    def test_create_folder_string_visibility
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id },{name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: '1'})
      assert_response 400
      match_json([bad_request_error_pattern('visibility', :not_included, list: [1, 2, 3, 4, 5, 6, 7].join(','), code: :datatype_mismatch, given_data_type: 'String', prepend_msg: :input_received)])
    end

    def test_create_folder_with_existing_name
      name = Solution::Folder.last.name
      post :create, construct_params({ id: get_category.id }, { name: name, description: Faker::Lorem.paragraph, visibility: 1 })
      match_json([bad_request_error_pattern('name', :'already exists in the selected category.')])
      assert_response 409
    end

    def test_create_folder_with_invalid_name
      post :create, construct_params({ id: get_category.id },  { name: 1, description: ['1'] })
      match_json([bad_request_error_pattern('name', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Integer),
                  bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Array),
                  bad_request_error_pattern('visibility', :missing_field)])
      assert_response 400
    end

    def test_create_folder_with_invalid_params
      post :create, construct_params({ id: get_category.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, field: Faker::Lorem.paragraph})
      match_json([bad_request_error_pattern('field', :invalid_field)])
      assert_response 400
    end

    def test_create_folder_in_unavailable_category_id
      post :create, construct_params({ id: 99999 }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1})
      assert_response :missing
    end

    def test_create_folder_in_unavailable_category_id_without_mandatory_fields
      post :create, construct_params({ id: 99999 }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1})
      assert_response :missing
    end

    # Visibility & Company ids validation
    def test_create_folder_with_valid_visibility_and_company_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 4, company_ids:[get_company.id] })
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.last))
    end

    def test_create_folder_with_valid_visibility_and_empty_company_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 4, company_ids:[] })
      assert_response 400
    end

    def test_create_folder_with_valid_company_ids_and_invalid_visibility
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 3, company_ids:[get_company.id] })
      assert_response 400
      match_json([bad_request_error_pattern('company_ids', :cant_set_company_ids, code: :incompatible_field)])
    end

    def test_create_folder_with_invalid_company_ids_and_invalid_visibility
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 3, company_ids:[99999] })
      assert_response 400
      match_json([bad_request_error_pattern('company_ids', :cant_set_company_ids, code: :incompatible_field)])
    end

    def test_create_folder_with_invalid_company_ids_and_valid_visibility
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 4, company_ids:[99999] })
      assert_response 400
      match_json([bad_request_error_pattern('company_ids', :invalid_company_ids , code: :invalid_company)])
    end


    def test_create_folder_with_string_company_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 4, company_ids:['99999'] })
      assert_response 400
      match_json([bad_request_error_pattern('company_ids', :array_datatype_mismatch, expected_data_type: 'Positive Integer', code: :datatype_mismatch)])
    end

    def test_create_folder_with_company_ids_having_duplicates
      category_meta = get_category
      company_id = get_company.id
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 4, company_ids:[company_id, company_id] })
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      assert Solution::FolderMeta.last.customer_ids == [company_id]
    end

    def test_create_folder_with_max_company_ids
      category_meta = get_category
      company_ids = Array.new(251) { rand(1...2) }
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 4, company_ids: company_ids })
      assert_response 400
      match_json([bad_request_error_pattern('company_ids', :too_long, current_count: company_ids.size, element_type: :elements, max_count: Solution::Constants::COMPANIES_LIMIT)])
    end

    def test_create_folder_with_visibility_selected_companies_without_company_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 4})
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.last))
    end

    def test_create_folder_without_visibility_and_with_company_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: Faker::Name.name, description: Faker::Lorem.paragraph, company_ids: @account.customer_ids })
      match_json([bad_request_error_pattern('visibility', :missing_field)])
      assert_response 400
    end

    def test_create_folder_translation
      language_code = @account.supported_languages.first
      folder = get_folder_without_translation_with_translated_category(language_code)
      params_hash = { name: Faker::Name.name, description: Faker::Lorem.paragraph }
      post :create, construct_params({id: folder.parent_id, language: language_code}, params_hash)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.last))
    end

    def test_create_folder_with_supported_language_without_description
      language_code = @account.supported_languages.first
      folder = get_folder_without_translation_with_translated_category(language_code)
      params_hash = { name: Faker::Name.name }
      post :create, construct_params({id: folder.parent_id, language: language_code}, params_hash)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.last))
    end

    def test_create_folder_with_supported_language_param
      language_code = @account.supported_languages.last
      folder = get_folder_without_translation_with_translated_category(language_code)
      params_hash = { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1 }
      post :create, construct_params({id: folder.parent_id, language: language_code}, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('visibility', :cant_set_for_secondary_language, code: :incompatible_field)])
    end

    def test_create_folder_with_supported_language_visibility_and_company_ids
      language_code = @account.supported_languages.last
      folder = get_folder_without_translation_with_translated_category(language_code)
      params_hash = { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 4, company_ids: [@account.customer_ids.last] }
      post :create, construct_params({id: folder.parent_id, language: language_code}, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('visibility', :cant_set_for_secondary_language, code: :incompatible_field)])
    end

    def test_create_folder_translation_for_unvailable_folder
      params_hash = {name: Faker::Name.name, description: Faker::Lorem.paragraph}
      language_code = @account.supported_languages.last
      post :create, construct_params({id: 99999, language: language_code}, params_hash)
      assert_response :missing
    end

    def test_create_folder_translation_for_primary_language
      folder = get_folder
      params_hash = {name: Faker::Name.name, description: Faker::Lorem.paragraph}
      language_code = @account.language
      post :create, construct_params({id: folder.parent_id, language: language_code}, params_hash)
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: language_code, list: (@account.supported_languages).sort.join(', ')))
    end

    def test_create_folder_translation_for_unvailable_category_translation
      Account.any_instance.stubs(:multilingual?).returns(true)
      params_hash = { name: Faker::Name.name, description: Faker::Lorem.paragraph }
      language_code = @account.supported_languages.first
      folder = get_folder_without_translation_without_translated_category
      post :create, construct_params({ id: folder.parent_id, language: language_code }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('category_id', :invalid_category_translation)])
    ensure
      Account.any_instance.unstub(:multilingual?)
    end

    # Update Folder
    def test_update_folder
      name = Faker::Name.name
      visibility = 4
      sample_folder = get_folder

      old_description = sample_folder.description
      old_name = sample_folder.name 

      params_hash  = { visibility: visibility, company_ids: [@account.customer_ids.last] }
      put :update, construct_params({ id: sample_folder.parent_id }, params_hash)
      assert_response 200
      match_json(solution_folder_pattern(sample_folder.reload))
      assert sample_folder.reload.name == old_name
      assert sample_folder.reload.description == old_description
      assert sample_folder.reload.solution_folder_meta.visibility == visibility
      assert sample_folder.reload.solution_folder_meta.customer_ids == [@account.customer_ids.last]
    end

    def test_update_folder_with_name_description
      name = Faker::Name.name
      description = Faker::Lorem.paragraph
      sample_folder = get_folder

      old_visibility = sample_folder.parent.visibility

      params_hash  = { name: name, description: description }
      put :update, construct_params({ id: sample_folder.parent_id }, params_hash)
      assert_response 200
      match_json(solution_folder_pattern(sample_folder.reload))
      assert sample_folder.reload.name == name
      assert sample_folder.reload.description == description
      assert sample_folder.reload.solution_folder_meta.visibility == old_visibility
    end

    def test_update_folder_with_primary_language_query_param_and_visibility
      name = Faker::Name.name
      description = Faker::Lorem.paragraph
      visibility = 3
      sample_folder = get_folder
      params_hash  = { name: name, description: description, visibility: visibility }
      put :update, construct_params({ id: sample_folder.parent_id, language: @account.language }, params_hash)
      assert_response 200
      match_json(solution_folder_pattern(sample_folder.reload))
      assert sample_folder.reload.name == name
      assert sample_folder.reload.description == description
      assert sample_folder.reload.solution_folder_meta.visibility == visibility
    end

    def test_update_folder_with_company_ids_and_invalid_visibility
      name = Faker::Name.name
      description = Faker::Lorem.paragraph
      visibility = 2
      company_ids = @account.company_ids
      sample_folder = get_folder
      params_hash  = { name: name, description: description, visibility: visibility, company_ids: company_ids }
      put :update, construct_params({ id: sample_folder.parent_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('company_ids', :cant_set_company_ids, code: :incompatible_field)])
    end

    def test_reindex_on_update_folder_with_company_visibility
      name = Faker::Name.name
      description = Faker::Lorem.paragraph
      visibility = 4
      company1 = create_company
      company2 = create_company
      sample_folder = create_folder
      sample_folder.add_visibility(Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users], [company1.id], false)
      Solution::FolderMeta.any_instance.expects(:update_search_index).once
      params_hash = { name: name, description: description, visibility: visibility, company_ids: [company1.id, company2.id] }
      put :update, construct_params({ id: sample_folder.parent_id }, params_hash)
      assert_response 200
    end

    def test_update_folder_with_company_ids_and_no_visibility
      folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], category_id: @account.solution_categories.last.id)
      create_customer_folders(folder_meta)
      company_ids = @account.company_ids
      params_hash = { company_ids: company_ids }
      put :update, construct_params({ id: folder_meta.id }, params_hash)
      assert_response 200
    end

    def test_update_unavailable_folder
      visibility = 4
      params_hash  = { visibility: visibility, company_ids: [@account.customer_ids.last] }
      put :update, construct_params({ id: 9999 }, params_hash)
      assert_response :missing
    end

    def test_update_unavailable_folder_translation
      language_code = @account.supported_languages.first
      sample_folder = get_folder_without_translation_with_translated_category(language_code)
      params_hash  = { name: name = Faker::Name.name }
      put :update, construct_params({ id: sample_folder.parent_id, language: language_code }, params_hash)
      assert_response :missing
    end

    def test_update_folder_with_boolean_visibility
      sample_folder = get_folder_without_translation_without_translated_category
      params_hash  = { visibility: false }
      put :update, construct_params({ id: sample_folder.parent_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('visibility', :not_included, list: [1, 2, 3, 4, 5, 6, 7].join(','))])
    end

    def test_update_folder_with_language_query
      name = Faker::Name.name
      description = Faker::Lorem.paragraph

      sample_folder = get_folder_with_translation
      solution_folder = sample_folder.solution_folder_meta.children.last
      language_code = Language.find(solution_folder.language_id).code
      params_hash  = { name: name, description: description }

      put :update, construct_params({ id: sample_folder.parent_id, language: language_code }, params_hash)
      assert_response 200

      match_json(solution_folder_pattern(solution_folder.reload))
      assert solution_folder.reload.name == name
      assert solution_folder.reload.description == description
    end

    # Delete Folder
    def test_delete_folder
      sample_folder = get_folder
      delete :destroy, construct_params(id: sample_folder.parent_id)
      assert_response 204
    end

    def test_delete_default_folder
      sample_folder = get_default_folder
      delete :destroy, construct_params(id: sample_folder.parent_id)
      assert_response 404
    end

    def test_delete_folder_with_language_param
      sample_folder = get_folder
      language_code = Language.find(sample_folder.language_id).code
      delete :destroy, construct_params({id: sample_folder.parent_id, language: language_code})
      assert_response 404
    end

    def test_delete_unavailable_folder
      delete :destroy, construct_params(id: 9999)
      assert_response :missing
    end

    # category_folder api/v2/solutions/categories/[id]/folders
    def test_index_category_folders
      sample_category_meta = get_category_with_folders
      get :category_folders, controller_params(id: sample_category_meta.id)
      assert_response 200
      result_pattern = []
      sample_category_meta.solution_folders.where('language_id = ?', @account.language_object.id).each do |f|
        result_pattern << solution_folder_pattern_index(f)
      end
      match_json(result_pattern.ordered!)
    end

    def test_index_category_folders_unavailable_category
      get :category_folders, controller_params(id: 999)
      assert_response :missing
    end

    def test_index_category_folders_with_language_param
      sample_category_meta = get_category_with_folders
      get :category_folders, controller_params(id: sample_category_meta.id, language: @account.language)
      assert_response 200
      result_pattern = []
      sample_category_meta.solution_folders.where('language_id = ?', @account.language_object.id).each do |f|
        result_pattern << solution_folder_pattern_index(f)
      end
      match_json(result_pattern.ordered!)
    end

    def test_index_category_folders_with_invalid_language_param
      sample_category_meta = get_category_with_folders
      get :category_folders, controller_params(id: sample_category_meta.id, language: 'adadfa')
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: 'adadfa', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
    end    

    # default index params test
    def test_index_with_invalid_page_and_per_page
      sample_category_meta = get_category_with_folders
      get :category_folders, controller_params(id: sample_category_meta.id, page: 'aaa', per_page: 'aaa')
      assert_response 400
      match_json([bad_request_error_pattern('page', :datatype_mismatch, expected_data_type: 'Positive Integer'),
        bad_request_error_pattern('per_page', :per_page_invalid, max_value: 100)])
    end

    def test_emoji_in_folder_name_and_description
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, {name: 'hey 😅 folder name', description: 'hey 😅 folder description', visibility: 1})
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      assert_equal UnicodeSanitizer.remove_4byte_chars('hey 😅 folder name'), result['name']
      assert_equal UnicodeSanitizer.remove_4byte_chars('hey 😅 folder description'), result['description']
    end

    # company filter visibility
    def test_create_folder_with_valid_visibility_and_company_filter_ids
      category_meta = get_category
      segment = create_company_segment
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 7, company_filter_ids: [segment.id] })
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.where(parent_id: result['id']).first))
    end

    def test_create_folder_with_valid_visibility_and_empty_company_filter_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 7, company_filter_ids: [] })
      assert_response 400
    end

    def test_create_folder_with_valid_company_filter_ids_and_invalid_visibility
      category_meta = get_category
      segment = create_company_segment
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 3, company_filter_ids: [segment.id] })
      assert_response 400
      match_json([bad_request_error_pattern('company_filter_ids', :cant_set_company_filter_ids, code: :incompatible_field)])
    end

    def test_create_folder_with_invalid_company_filter_ids_and_invalid_visibility
      category_meta = get_category
      segment = create_company_segment
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 3, company_filter_ids: [999_999] })
      assert_response 400
      match_json([bad_request_error_pattern('company_filter_ids', :cant_set_company_filter_ids, code: :incompatible_field)])
    end

    def test_create_folder_with_invalid_company_filter_and_valid_visibility
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 7, company_filter_ids: [999_999] })
      assert_response 400
      match_json([bad_request_error_pattern('company_filter_ids', :invalid_company_filter_ids, code: :invalid_company_filter)])
    end

    def test_create_folder_with_string_company_filter_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 7, company_filter_ids: ['999_999'] })
      assert_response 400
      match_json([bad_request_error_pattern('company_filter_ids', :array_datatype_mismatch, expected_data_type: 'Positive Integer', code: :datatype_mismatch)])
    end

    def test_create_folder_with_company_filter_ids_having_duplicates
      category_meta = get_category
      segment = create_company_segment
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 7, company_filter_ids: [segment.id, segment.id] })
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      assert Solution::FolderMeta.where(id: result['id']).first.company_filter_ids == [segment.id]
    end

    def test_create_folder_with_max_company_filter_ids
      category_meta = get_category
      company_filter_ids = Array.new(251) { rand(1...2) }
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 7, company_filter_ids: company_filter_ids })
      assert_response 400
      match_json([bad_request_error_pattern('company_filter_ids', :too_long, current_count: company_filter_ids.size, element_type: :elements, max_count: Solution::Constants::COMPANY_FILTER_LIMIT)])
    end

    def test_create_folder_with_visibility_selected_company_filters_without_company_filter_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 7 })
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.where(parent_id: result['id']).first))
    end

    def test_create_folder_without_visibility_and_with_company_filter_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, company_filter_ids: @account.company_filter_ids })
      match_json([bad_request_error_pattern('visibility', :missing_field)])
      assert_response 400
    end

    def test_update_folder_with_company_filter_ids_and_valid_visibility
      folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_segment], category_id: @account.solution_categories.last.id)
      visibility = 7
      segment = create_company_segment
      sample_folder = get_folder
      params_hash = { visibility: visibility, company_filter_ids: [segment.id] }
      put :update, construct_params({ id: folder_meta.parent_id }, params_hash)
      assert_response 200
    end

    def test_update_folder_with_company_filter_ids_and_has_valid_segment_folder_record
      segment1 = create_company_segment
      folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_segment], category_id: @account.solution_categories.last.id, company_filter_ids: [segment1.id])
      visibility = 7
      segment2 = create_company_segment
      sample_folder = get_folder
      params_hash = { visibility: visibility, company_filter_ids: [segment2.id] }
      put :update, construct_params({ id: folder_meta.parent_id }, params_hash)
      assert_response 200
      Solution::FolderVisibilityMapping.where(folder_meta_id: folder_meta.id).count == 1
      Solution::FolderVisibilityMapping.where(folder_meta_id: folder_meta.id).first == [segment2.id]
    end

    # contact filter visibility
    def test_create_folder_with_valid_visibility_and_contact_filter_ids
      category_meta = get_category
      segment = create_contact_segment
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 6, contact_filter_ids: [segment.id] })
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.where(parent_id: result['id']).first))
    end

    def test_create_folder_with_valid_visibility_and_empty_contact_filter_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 6, contact_filter_ids: [] })
      assert_response 400
    end

    def test_create_folder_with_valid_contact_filter_ids_and_invalid_visibility
      category_meta = get_category
      segment = create_contact_segment
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 3, contact_filter_ids: [segment.id] })
      assert_response 400
      match_json([bad_request_error_pattern('contact_filter_ids', :cant_set_contact_filter_ids, code: :incompatible_field)])
    end

    def test_create_folder_with_invalid_contact_filter_ids_and_invalid_visibility
      category_meta = get_category
      segment = create_contact_segment
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 7, contact_filter_ids: [999_999] })
      assert_response 400
      match_json([bad_request_error_pattern('contact_filter_ids', :cant_set_contact_filter_ids, code: :incompatible_field)])
    end

    def test_create_folder_with_invalid_contact_filter_and_valid_visibility
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 6, contact_filter_ids: [999_999] })
      assert_response 400
      match_json([bad_request_error_pattern('contact_filter_ids', :invalid_contact_filter_ids, code: :invalid_contact_filter)])
    end

    def test_create_folder_with_string_contact_filter_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 6, contact_filter_ids: ['99999'] })
      assert_response 400
      match_json([bad_request_error_pattern('contact_filter_ids', :array_datatype_mismatch, expected_data_type: 'Positive Integer', code: :datatype_mismatch)])
    end

    def test_create_folder_with_contact_filter_ids_having_duplicates
      category_meta = get_category
      segment = create_contact_segment
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 6, contact_filter_ids: [segment.id, segment.id] })
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      assert Solution::FolderMeta.where(id: result['id']).first.contact_filter_ids == [segment.id]
    end

    def test_create_folder_with_max_contact_filter_ids
      category_meta = get_category
      contact_filter_ids = Array.new(251) { rand(1...2) }
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 6, contact_filter_ids: contact_filter_ids })
      assert_response 400
      match_json([bad_request_error_pattern('contact_filter_ids', :too_long, current_count: contact_filter_ids.size, element_type: :elements, max_count: Solution::Constants::CONTACT_FILTER_LIMIT)])
    end

    def test_create_folder_with_visibility_selected_contact_filters_without_contact_filter_ids
      category_meta = get_category
      post :create, construct_params({ id: category_meta.id }, { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 6 })
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.where(parent_id: result['id']).first))
    end

    def test_update_folder_with_contact_filter_ids_and_valid_visibility
      folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:contact_segment], category_id: @account.solution_categories.last.id)
      visibility = 6
      segment = create_contact_segment
      sample_folder = get_folder
      params_hash = { visibility: visibility, contact_filter_ids: [segment.id] }
      put :update, construct_params({ id: folder_meta.parent_id }, params_hash)
      assert_response 200
    end

    def test_update_folder_with_contact_filter_ids_and_has_valid_segment_folder_record
      segment1 = create_contact_segment
      folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:contact_segment], category_id: @account.solution_categories.last.id, contact_filter_ids: [segment1.id])
      visibility = 6
      segment2 = create_contact_segment
      sample_folder = get_folder
      params_hash = { visibility: visibility, contact_filter_ids: [segment2.id] }
      put :update, construct_params({ id: folder_meta.parent_id }, params_hash)
      assert_response 200
      Solution::FolderVisibilityMapping.where(folder_meta_id: folder_meta.id).count == 1
      Solution::FolderVisibilityMapping.where(folder_meta_id: folder_meta.id).first == [segment2.id]
    end

    # Activity tests
    def test_activity_record_for_folder_create
      activities_count = Helpdesk::Activity.count
      category_meta = get_category
      params_hash = { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1 }
      post :create, construct_params({ id: category_meta.id }, params_hash)
      assert_response 201
      activity_record = Helpdesk::Activity.last
      action_name = activity_record.description.split('.')[2]
      assert_equal Helpdesk::Activity.count, activities_count + 1
      assert_equal activity_record.activity_data[:title], params_hash[:name]
      assert_equal action_name, 'new_folder'
    end

    def test_activity_record_for_folder_update
      activities_count = Helpdesk::Activity.count
      sample_folder = get_folder
      params_hash = { name: Faker::Name.name }
      put :update, construct_params({ id: sample_folder.parent_id }, params_hash)
      assert_response 200
      activity_record = Helpdesk::Activity.last
      action_name = activity_record.description.split('.')[2]
      assert_equal Helpdesk::Activity.count, activities_count + 1
      assert_equal activity_record.activity_data[:title], params_hash[:name]
      assert_equal activity_record.notable_type, 'Solution::Folder'
      assert_equal action_name, 'rename_actions'
    end

    def test_activity_record_for_folder_update_visibility
      activities_count = Helpdesk::Activity.count
      sample_folder = get_folder
      params_hash = { visibility: 3 }
      put :update, construct_params({ id: sample_folder.parent_id }, params_hash)
      assert_response 200
      activity_record = Helpdesk::Activity.last
      action_name = activity_record.description.split('.')[2]
      assert_equal Helpdesk::Activity.count, activities_count + 1
      assert_equal activity_record.activity_data[:title], sample_folder.name
      assert_equal activity_record.notable_type, 'Solution::Folder'
      assert_equal action_name, 'folder_visibility_update'
      assert_equal activity_record.activity_data[:solutions_properties][1], params_hash[:visibility]
    end

    def test_activity_record_for_folder_update_category
      activities_count = Helpdesk::Activity.count
      sample_folder = get_folder
      category = @account.solution_categories.last
      params_hash = { category_id: category.id }
      put :update, construct_params({ id: sample_folder.parent_id }, params_hash)
      assert_response 200
      activity_record = Helpdesk::Activity.last
      action_name = activity_record.description.split('.')[2]
      assert_equal Helpdesk::Activity.count, activities_count + 1
      assert_equal activity_record.activity_data[:title], sample_folder.name
      assert_equal activity_record.notable_type, 'Solution::Folder'
      assert_equal action_name, 'folder_category_update'
      assert_equal activity_record.activity_data[:solutions_properties][1], category.name
    end

    def test_activity_record_for_folder_delete
      activities_count = Helpdesk::Activity.count
      sample_folder = get_folder
      folder_name = sample_folder.name
      delete :destroy, construct_params(id: sample_folder.parent_id)
      assert_response 204
      activity_record = Helpdesk::Activity.all[activities_count]
      action_name = activity_record.description.split('.')[2]
      assert Helpdesk::Activity.count > activities_count
      assert_equal activity_record.activity_data[:title], folder_name
      assert_equal action_name, 'delete_folder'
    end
  end
end
