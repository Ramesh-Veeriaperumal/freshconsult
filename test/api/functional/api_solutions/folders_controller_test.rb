require_relative '../../test_helper'
module ApiSolutions
  class FoldersControllerTest < ActionController::TestCase
    include SolutionsTestHelper

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run
      @account.launch(:translate_solutions)
      additional = @account.account_additional_settings
      additional.supported_languages = ["es","ru-RU"]
      additional.save
      @account.features.enable_multilingual.create
      @account.reload
      @@initial_setup_run = true
    end

    def create_company
      company = Company.create(name: Faker::Name.name, account_id: @account.id)
      company.save
      company
    end

    def get_company
      company ||= create_company
    end

    def wrap_cname(params)
      { folder: params }
    end

    def meta_scoper
      @account.solution_folder_meta.where(is_default: false)
    end

    def get_folder
      meta_scoper.collect{ |x| x.children }.flatten.first
    end

    def get_category
      @account.solution_category_meta.where(is_default: false).first
    end

    def get_category_with_folders
      @account.solution_category_meta.where(is_default: false).select { |x| x if x.children.count > 0 }.first
    end

    def get_folder_without_translation
      meta_scoper.select{|x| x.children if x.children.count == 1}.first
    end

    def get_folder_with_translation
      meta_scoper.select{|x| x.children if x.children.count > 1}.first
    end

    def get_default_folder
      @account.solution_folder_meta.where(is_default: true).first.children.first
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
      sample_folder = get_folder_without_translation
      get :show, controller_params(id: sample_folder.parent_id, language: @account.supported_languages.first)
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
      allowed_features = Account.first.features.where(' type not in (?) ', ['EnableMultilingualFeature'])
      Account.any_instance.stubs(:features).returns(allowed_features)
      sample_folder = get_folder
      get :show, controller_params({id: sample_folder.parent_id, language: @account.language })
      match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      assert_response 404
    ensure
      Account.any_instance.unstub(:features)
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
      match_json([bad_request_error_pattern('visibility', :not_included, list: [1,2,3,4].join(','),code: :datatype_mismatch, given_data_type: 'String', prepend_msg: :input_received)])
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
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.last))
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
      match_json([bad_request_error_pattern('company_ids', :invalid_list, list: '99999')])
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
      folder = get_folder_without_translation
      params_hash = {name: Faker::Name.name, description: Faker::Lorem.paragraph}
      language_code = @account.supported_languages.first
      post :create, construct_params({id: folder.parent_id, language: language_code}, params_hash)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.last))
    end

    def test_create_folder_with_supported_language_without_description
      folder = get_folder_without_translation
      params_hash = {name: Faker::Name.name}
      language_code = @account.supported_languages.first
      post :create, construct_params({id: folder.parent_id, language: language_code}, params_hash)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
      match_json(solution_folder_pattern(Solution::Folder.last))
    end

    def test_create_folder_with_supported_language_param
      folder = get_folder_without_translation
      params_hash = {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1}
      language_code = @account.supported_languages.last
      post :create, construct_params({id: folder.parent_id, language: language_code}, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('visibility', :cant_set_for_secondary_language, code: :incompatible_field)])
    end

    def test_create_folder_with_supported_language_visibility_and_company_ids
      folder = get_folder_without_translation
      params_hash = {name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 4, company_ids: [@account.customer_ids.last]}
      language_code = @account.supported_languages.last
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

    def test_update_unavailable_folder
      visibility = 4
      params_hash  = { visibility: visibility, company_ids: [@account.customer_ids.last] }
      put :update, construct_params({ id: 9999 }, params_hash)
      assert_response :missing
    end

    def test_update_unavailable_folder_translation
      sample_folder = get_folder_without_translation
      params_hash  = { name: name = Faker::Name.name }
      put :update, construct_params({ id: sample_folder.parent_id, language: @account.supported_languages.first }, params_hash)
      assert_response :missing
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
  end
end