require_relative '../../test_helper'

class ApiSolutionCategoriesFlowsTest < ActionDispatch::IntegrationTest

  def get_meta_without_translation
    @account.solution_category_meta.where(is_default:false).select{|x| x.children if x.children.count == 1}.first
  end

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

  def test_create_category_with_language_query_param
    payload = { name: Faker::Name.name, description: Faker::Lorem.paragraph }.to_json
    skip_bullet do
      post('/api/v2/solutions/categories/en', payload, @write_headers)
      assert_response 405
    end
  end

  def test_create_category
    payload = { name: Faker::Name.name, description: Faker::Lorem.paragraph }.to_json
    skip_bullet do
      post('/api/v2/solutions/categories', payload, @write_headers)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/categories/#{result['id']}", response.headers['Location']
    end
  end

  def test_create_translation
  	id = get_meta_without_translation.parent_id
  	language_code = @account.supported_languages.first
    payload = { name: Faker::Name.name, description: Faker::Lorem.paragraph }.to_json
    skip_bullet do
      post("/api/v2/solutions/categories/#{id}/#{language_code}", payload, @write_headers)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/categories/#{result['id']}", response.headers['Location']
    end
  end

  def test_show_category
    id = get_meta_without_translation.parent_id
    language_code = @account.language
    skip_bullet do
      get("/api/v2/solutions/categories/#{id}/#{language_code}", nil, @headers)
      assert_response 200
    end
  end

  def test_update_category
    payload = { name: Faker::Name.name, description: Faker::Lorem.paragraph }.to_json
    id = get_meta_without_translation.parent_id
    language_code = @account.language
    skip_bullet do
      put("/api/v2/solutions/categories/#{id}/#{language_code}", payload, @write_headers)
      assert_response 200
    end
  end

  def test_show_folders
    id = get_meta_without_translation.parent_id
    language_code = @account.supported_languages.first
    skip_bullet do
      get("/api/v2/solutions/categories/#{id}/folders", nil, @headers)
      assert_response 200
    end
  end

  def test_create_folder
    id = get_meta_without_translation.parent_id
    payload = { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1 }.to_json
    skip_bullet do
      post("/api/v2/solutions/categories/#{id}/folders", payload, @write_headers)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
    end
  end

  def test_show_categories
    language_code = @account.supported_languages.first
    skip_bullet do
      get("/api/v2/solutions/categories/#{language_code}", nil, @headers)
      assert_response 200
    end
  end
end