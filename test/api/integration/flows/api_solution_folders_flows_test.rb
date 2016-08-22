require_relative '../../test_helper'

class ApiSolutionFoldersFlowsTest < ActionDispatch::IntegrationTest
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

  def setup_categories
    @categorymeta1 = Solution::CategoryMeta.new
    @categorymeta1.account_id = @account.id
    @categorymeta1.save

    @category1 = Solution::Category.new
    @category1.name = Faker::Name.name
    @category1.description = Faker::Lorem.paragraph
    @category1.account_id = @account.id
    @category1.solution_category_meta = @categorymeta1
    @category1.save
  end

  def meta_scoper
    @account.solution_folder_meta.where(is_default: false)
  end

  def get_folder
    meta_scoper.collect{ |x| x.children }.flatten.first
  end

  def get_folder_without_translation
    meta_scoper.map{|x| x.children if x.children.count == 1}.flatten.reject(&:blank?).first
  end

  def test_create_folder_with_language_query_param
    payload = { name: Faker::Name.name, description: Faker::Lorem.paragraph, visibility: 1 }.to_json
    skip_bullet do
      post('/api/v2/solutions/folders/en', payload, @write_headers)
      assert_response 404
    end
  end

  def test_create_folder_translation
  	payload = { name: Faker::Name.name, description: Faker::Lorem.paragraph }.to_json
  	sample_folder = get_folder_without_translation
  	language_code = @account.supported_languages.first
  	skip_bullet do
      post("/api/v2/solutions/folders/#{sample_folder.parent_id}/#{language_code}", payload, @write_headers)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/folders/#{result['id']}", response.headers['Location']
    end
  end

  def test_create_article
    payload = { title: Faker::Name.name, description: Faker::Lorem.paragraph, status: 1, type: 1 }.to_json
    sample_folder = get_folder
    skip_bullet do
      post("/api/v2/solutions/folders/#{sample_folder.parent_id}/articles", payload, @write_headers)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
    end
  end

  def test_get_articles
    sample_folder = get_folder
    skip_bullet do
      get("/api/v2/solutions/folders/#{sample_folder.parent_id}/articles", nil, @headers)
      assert_response 200
    end
  end

  def test_show_folder
    sample_folder = get_folder
    language_code = @account.language
    skip_bullet do
      get("/api/v2/solutions/folders/#{sample_folder.parent_id}/#{language_code}", nil, @headers)
      assert_response 200
    end
  end

  def test_update_folder
    payload = { name: Faker::Name.name, description: Faker::Lorem.paragraph }.to_json
    sample_folder = get_folder_without_translation
    language_code = @account.language
    skip_bullet do
      put("/api/v2/solutions/folders/#{sample_folder.parent_id}/#{language_code}", payload, @write_headers)
      assert_response 200
    end
  end
end