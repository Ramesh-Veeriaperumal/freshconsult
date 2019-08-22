require_relative '../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

module ApiSearch
  class SolutionsControllerTest < ActionController::TestCase
    include SolutionsHelper
    include SolutionBuilderHelper
    include SearchTestHelper
    include PrivilegesHelper

    def setup
      super
      before_all
    end

    @before_all_run = false

    def before_all
      subscription = @account.subscription
      subscription.state = 'active'
      subscription.save
      @account.reload
      @before_all_run = true
    end

    def article_params(folder_visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
      category = create_category
      {
        title: "Test",
        description: "Test",
        folder_id: create_folder(visibility: folder_visibility, category_id: category.id).id
      }
    end

    def test_results_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      post :results, construct_params(version: 'private', context: 'spotlight', term: Faker::Lorem.word, limit: 3)
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end

    def test_results_public_api
      Solutions::ArticleDecorator.any_instance.stubs(:private_api?).returns(false)
      article = create_article(article_params).primary_article
      stub_private_search_response([article]) do
        post :results, construct_params(term: article.title, limit: 3)
      end
      assert_response 200
      match_json [public_search_solution_article_pattern(article)]
    ensure
      Solutions::ArticleDecorator.any_instance.unstub(:private_api?)
    end

    def test_results_with_valid_params
      article = create_article(article_params).primary_article
      stub_private_search_response([article]) do
        post :results, construct_params(version: 'private', context: 'spotlight', term: article.title, limit: 3)
      end
      assert_response 200
      match_json [search_solution_article_pattern(article)]
    end

    def test_results_with_insert_solutions_context
      article = create_article(article_params).primary_article
      stub_private_search_response([article]) do
        post :results, construct_params(version: 'private', context: 'insert_solutions', term: article.title, limit: 3)
      end
      assert_response 200
      match_json [search_solution_article_pattern(article, :agent_insert_solution)]
    end

    def test_results_with_bot_map_context
      article = create_article(article_params).primary_article
      stub_private_search_response([article]) do
        post :results, construct_params(version: 'private', context: 'bot_map_solution', term: article.title, limit: 3)
      end
      assert_response 200
      match_json [search_solution_article_pattern(article, :filtered_solution_search)]
    end

    def test_results_without_solutions_privilege
      User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
      post :results, construct_params(version: 'private', context: 'spotlight', term: Faker::Lorem.word, limit: 3)
      assert_response 403
      User.any_instance.unstub(:privilege?)
    end
  end
end
