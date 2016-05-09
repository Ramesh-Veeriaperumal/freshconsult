require_relative '../../test_helper'

class ApiSolutionArticlesQueriesTest < ActionDispatch::IntegrationTest
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
    setup_articles
    @@initial_setup_run = true
  end

  def setup_articles
    @articlemeta = Solution::ArticleMeta.new
    @articlemeta.art_type = 1
    @articlemeta.solution_folder_meta_id = Solution::FolderMeta.first.id
    @articlemeta.account_id = @account.id
    @articlemeta.published = false
    @articlemeta.save

    @article = Solution::Article.new
    @article.title = "Sample"
    @article.description = "<b>aaa</b>"
    @article.status = 1
    @article.language_id = @account.language_object.id
    @article.parent_id = @articlemeta.id
    @article.account_id = @account.id
    @article.user_id = @account.agents.first.id
    @article.save
  end

  def get_article
    @account.solution_article_meta.map{ |x| x.children }.flatten.reject(&:blank?).first
  end

  def get_article_without_translation
    @account.solution_article_meta.map{ |x| x.children if x.children.count == 1}.flatten.reject(&:blank?).first
  end

  def test_create_articles_with_language_query_param
    payload = { title: Faker::Name.name, description: Faker::Lorem.paragraph, status: 1, type: 2 }.to_json
    skip_bullet do
      post('/api/v2/solutions/articles/en', payload, @write_headers)
      assert_response 404
    end
  end

  def test_create_translation
  	payload = { title: Faker::Name.name, description: Faker::Lorem.paragraph, status: 1, category_name: 'category_name', folder_name: 'folder_name' }.to_json
  	sample_article = get_article_without_translation
  	language_code = @account.supported_languages.first
  	skip_bullet do
  		post("api/v2/solutions/articles/#{sample_article.parent_id}/#{language_code}", payload, @write_headers)
  		assert_response 201
  	end
  end

  def test_show_article
  	sample_article = get_article
  	language_code = @account.language
  	skip_bullet do
  		get("api/v2/solutions/articles/#{sample_article.parent_id}/#{language_code}", nil, @headers)
  		assert_response 200
  	end
  end

  def test_update_article
  	payload = { title: Faker::Name.name, description: Faker::Lorem.paragraph }.to_json
  	sample_article = get_article
  	language_code = @account.language
  	skip_bullet do
  		put("api/v2/solutions/articles/#{sample_article.parent_id}/#{language_code}", payload, @write_headers)
  		assert_response 200
  	end
  end
end