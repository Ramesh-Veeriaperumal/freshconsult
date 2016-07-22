require_relative '../../test_helper'
module ApiSolutions
  class CategoriesControllerTest < ActionController::TestCase
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
      p = Portal.new
      p.name = "Sample Portal"
      p.account_id  = @account.id
      p.save
      @account.features.enable_multilingual.create
      @account.reload
      @@initial_setup_run = true
    end

    def wrap_cname(params)
      { category: params }
    end

    # refactor logic
    def get_category
      @account.solution_category_meta.where(is_default:false).select{ |x| x.children}.first
    end

    def get_meta_with_translation
      @account.solution_category_meta.where(is_default:false).select{|x| x.children if x.children.count > 1}.first
    end

    def get_meta_without_translation
      @account.solution_category_meta.where(is_default:false).select{|x| x.children if x.children.count == 1}.first
    end

    def test_show_category
      sample_category = get_category
      get :show, controller_params(id: sample_category.parent_id)
      match_json(solution_category_pattern(sample_category))
      assert_response 200
    end

    def test_show_unavailalbe_category
      get :show, controller_params(id: 99999)
      assert_response :missing
    end

    def test_show_category_with_unavailable_translation
      sample_category = get_meta_without_translation
      get :show, controller_params(id: sample_category.id, language: @account.supported_languages.first)
      assert_response :missing
    end


    def test_show_category_with_language_query_param
      sample_category = get_category
      get :show, controller_params(id: sample_category.parent_id, language: @account.language)
      match_json(solution_category_pattern(sample_category))
      assert_response 200
    end

    def test_show_category_with_invalid_language_query_param
      sample_category = get_category
      get :show, controller_params(id: sample_category.parent_id, language: 'adadfs')
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: 'adadfs', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
    end

    # Feature Check
    def test_show_category_with_language_query_param_without_multilingual_feature
      allowed_features = Account.first.features.where(' type not in (?) ', ['EnableMultilingualFeature'])
      Account.any_instance.stubs(:features).returns(allowed_features)
      sample_category = get_category
      get :show, controller_params({id: sample_category.parent_id, language: @account.language })
      match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      assert_response 404
    ensure
      Account.any_instance.unstub(:features)
    end

    # Create Category
    def test_create_category
      post :create, construct_params({},  name: Faker::Name.name, description: Faker::Lorem.paragraph)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/categories/#{result['id']}", response.headers['Location']
      match_json(solution_category_pattern(Solution::Category.last))
    end

    def test_create_category_without_description
      post :create, construct_params({},  name: Faker::Name.name)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/categories/#{result['id']}", response.headers['Location']
      match_json(solution_category_pattern(Solution::Category.last))
    end

    def test_create_category_without_name
      post :create, construct_params({},{})
      match_json([bad_request_error_pattern('name', :datatype_mismatch, code: :missing_field, expected_data_type: String)])
      assert_response 400
    end

    def test_create_category_with_existing_name
      name = Solution::Category.last.name
      post :create, construct_params({},  name: name, description: Faker::Lorem.paragraph)
      match_json([bad_request_error_pattern('name', :'has already been taken')])
      assert_response 409
    end

    def test_create_category_with_invalid_name
      post :create, construct_params({},  name: 1, description: 1)
      match_json([bad_request_error_pattern('name', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Integer),
                  bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Integer)])
      assert_response 400
    end

    def test_create_category_with_invalid_params
      post :create, construct_params({}, {name: Faker::Name.name, description: Faker::Lorem.paragraph, field: Faker::Lorem.paragraph})
      match_json([bad_request_error_pattern('field', :invalid_field)])
      assert_response 400
    end

    def test_create_category_with_visible_in
      post :create, construct_params({}, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visible_in_portals: [@account.main_portal.id]})
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/categories/#{result['id']}", response.headers['Location']
      match_json(solution_category_pattern(Solution::Category.last))
    end

    def test_create_category_with_visible_in_without_multiple_portals
      portals = [@account.portals.first]
      Account.any_instance.stubs(:portals).returns(portals)
      post :create, construct_params({}, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visible_in_portals: [9999]})
      match_json([bad_request_error_pattern('visible_in_portals', :multiple_portals_required, code: :incompatible_field)])
      assert_response 400
    ensure
      Account.any_instance.unstub(:portals)
    end


    def test_create_category_with_invalid_visible_in
      post :create, construct_params({}, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visible_in_portals: [9999]})
      match_json([bad_request_error_pattern('visible_in_portals', :invalid_list, list: '9999')])
      assert_response 400
    end

    def test_create_category_with_invalid_datatype_in_visible_in
      post :create, construct_params({}, {name: Faker::Name.name, description: Faker::Lorem.paragraph, visible_in_portals: ['9999']})
      match_json([bad_request_error_pattern('visible_in_portals', :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
      assert_response 400
    end

    def test_create_category_with_name_exceeding_max_length
      post :create, construct_params({}, {name: 'a'*260, description: Faker::Lorem.paragraph })
      assert_response 400
      match_json([bad_request_error_pattern('name', :too_long, current_count: 260, element_type: 'characters', max_count: ApiConstants::MAX_LENGTH_STRING)])
    end

    def test_create_translation
      sample_category_meta = get_meta_without_translation
      language_code = @account.supported_languages.first
      params_hash  = { name: Faker::Name.name, description: Faker::Lorem.paragraph }
      post :create, construct_params({id: sample_category_meta.id, language: language_code}, params_hash)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/categories/#{result['id']}", response.headers['Location']
      match_json(solution_category_pattern(Solution::Category.last))
    end

    def test_create_translation_without_description
      sample_category_meta = get_meta_without_translation
      language_code = @account.supported_languages.last
      params_hash  = { name: Faker::Name.name }
      post :create, construct_params({id: sample_category_meta.id, language: language_code}, params_hash)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/categories/#{result['id']}", response.headers['Location']
      match_json(solution_category_pattern(Solution::Category.last))
    end

    def test_create_translation_with_primary_language_param
      sample_category_meta = get_meta_without_translation
      language_code = @account.language
      params_hash  = { name: Faker::Name.name, description: Faker::Lorem.paragraph }
      post :create, construct_params({id: sample_category_meta.id, language: language_code}, params_hash)
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: language_code, list: (@account.supported_languages).sort.join(', ')))
    end

    def test_create_translation_with_invalid_languge
      sample_category_meta = get_meta_without_translation
      language_code = @account.supported_languages.first
      params_hash  = { name: Faker::Name.name, description: Faker::Lorem.paragraph }
      post :create, construct_params({id: sample_category_meta.id, language: 'aa'}, params_hash)
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: 'aa', list: (@account.supported_languages).sort.join(', ')))
    end

    # Update Category
    def test_update_category  
      name = Faker::Name.name
      description = Faker::Lorem.paragraph
      sample_category = get_category
      params_hash  = { name: name, description: description, visible_in_portals: [@account.portal_ids.last] }
      put :update, construct_params({ id: sample_category.id }, params_hash)
      assert_response 200
      match_json(solution_category_pattern(sample_category.reload))
      assert sample_category.reload.name == name
      assert sample_category.reload.description == description
      assert sample_category.reload.solution_category_meta.portal_ids == [@account.portal_ids.last]
    end

    def test_update_category_with_empty_description
      sample_category = get_category
      params_hash  = { description: nil }
      put :update, construct_params({ id: sample_category.id }, params_hash)
      assert_response 200
      match_json(solution_category_pattern(sample_category.reload))
      assert sample_category.reload.description == nil
    end

    def test_update_unavailable_category
      name = Faker::Name.name
      description = Faker::Lorem.paragraph
      params_hash  = { name: name, description: description, visible_in_portals: [@account.portal_ids.last] }
      put :update, construct_params({ id: 9999 }, params_hash)
      assert_response :missing
    end

    def test_update_category_visible_in
      sample_category = get_category
      old_name = sample_category.name
      old_description = sample_category.description
      params_hash  = { visible_in_portals: [@account.portal_ids.last] }
      put :update, construct_params({ id: sample_category.id }, params_hash)
      assert_response 200
      match_json(solution_category_pattern(sample_category.reload))
      assert sample_category.reload.name == old_name
      assert sample_category.reload.description == old_description
      assert sample_category.reload.solution_category_meta.portal_ids == [@account.portal_ids.last]
    end

    def test_update_category_description
      sample_category = get_category
      old_name = sample_category.name
      description = Faker::Lorem.paragraph
      params_hash  = { description: description }
      put :update, construct_params({ id: sample_category.id }, params_hash)
      assert_response 200
      match_json(solution_category_pattern(sample_category.reload))
      assert sample_category.reload.name == old_name
      assert sample_category.reload.description == description
    end

    # Update category without translation
    def test_update_category_with_language_query_param_case_1
      name = Faker::Name.name
      description = Faker::Lorem.paragraph
      sample_category_meta = get_meta_without_translation
      language_code = @account.supported_languages.first
      params_hash  = { name: name, description: description }

      put :update, construct_params({ id: sample_category_meta.id, language: language_code }, params_hash)
      assert_response :missing
    end

    # Update category with translation
    def test_update_category_with_language_query_param_case_2
      name = Faker::Name.name
      description = Faker::Lorem.paragraph
      sample_category_meta = get_meta_with_translation

      solution_category = sample_category_meta.children.last
      language_code = Language.find(solution_category.language_id).code
      
      params_hash  = { name: name, description: description }
      put :update, construct_params({ id: sample_category_meta.id, language: language_code }, params_hash)
      assert_response 200

      match_json(solution_category_pattern(solution_category.reload))
      assert solution_category.reload.name == name
      assert solution_category.reload.description == description
    end

    def test_update_category_description
      description = Faker::Lorem.paragraph
      sample_category = get_category
      params_hash  = { description: description }
      put :update, construct_params({ id: sample_category.id }, params_hash)
      assert_response 200
      match_json(solution_category_pattern(sample_category.reload))
      assert sample_category.reload.description == description
    end

    # Delete Category
    def test_delete_category
      sample_category = get_category
      delete :destroy, construct_params(id: sample_category.id)
      assert_response 204
    end

    def test_delete_unavailable_category
      delete :destroy, construct_params(id: 9999)
      assert_response :missing
    end

    def test_delete_default_category
      delete :destroy, construct_params(id: 1)
      assert_response :missing
    end

    def test_delete_category_with_language_param
      sample_category = get_category
      language_code = Language.find(sample_category.language_id).code
      delete :destroy, construct_params({id: sample_category.id, language: language_code})
      assert_response 404
    end

    # Index
    def test_index
      get :index, controller_params
      assert_response 200
      categories = @account.solution_categories.where('language_id = ?',@account.language_object.id)
      pattern = categories.map { |category| solution_category_pattern(category) }
      match_json(pattern.ordered!)
    end

    def test_index_with_language_param
      get :index, construct_params(language: @account.language)
      assert_response 200
      categories = @account.solution_categories.where('language_id = ?',@account.language_object.id)
      pattern = categories.map { |category| solution_category_pattern(category) }
      match_json(pattern.ordered!)
    end

    def test_index_with_invalid_language_param
      get :index, construct_params(language: 'aaa')
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: 'aaa', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
    end

    # Query Params test
    def test_update_category_with_language_in_JSON
      sample_category_meta = get_meta_without_translation
      params_hash  = { name: Faker::Name.name, description: Faker::Lorem.paragraph, language: 'en' }
      put :update, construct_params({ id: sample_category_meta.id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('language', :invalid_field)])
    end
  end
end