require_relative '../../test_helper'

class ApiSolutionArticleQueriesTest < ActionDispatch::IntegrationTest
  include SolutionsTestHelper

  @@initial_setup_run = true

  def initial_setup
    return if @@initial_setup_run
    @category_meta = Solution::CategoryMeta.new(account_id: @account.id, is_default: false )
    @category_meta.save

    @category = Solution::Category.new(account_id: @account.id, language_id: 6, name: "Sample", description: "Sample")
    @category.parent = @category_meta
    @category.save

    @@initial_setup_run = true
  end

  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 7,
        api_update: 6,
        api_show: 6,
        api_index: 8,
        api_destroy: 23,

        create: 39,
        update: 27,
        show: 17,
        index: 20,
        destroy: 37,
      }

      folder = @account.solution_folder_meta.where(is_default: false).first
      folder_id = folder.id
      category_id = folder.solution_category_meta.id

      # create
      v1[:create] = count_queries do
        post("/solution/categories/#{category_id}/folders/#{folder_id}/articles.json", v1_article_payload(folder_id), @write_headers)
        assert_response 200
      end
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post("/api/v2/solutions/folders/#{folder_id}/articles", v2_article_payload, @write_headers)
        assert_response 201
      end

      # Query in create.json.api
      # 3 queries for tags
      v2[:create] -= 4

      ids = Solution::ArticleMeta.last(2).map(&:id).sort

      # update
      v1[:update] = count_queries do
        put("/solution/categories/#{category_id}/folders/#{folder_id}/articles/#{ids[0]}.json", v1_article_update_payload, @write_headers)
        assert_response 200
      end
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/v2/solutions/articles/#{ids[1]}", v2_article_update_payload, @write_headers)
        assert_response 200
      end

      # show
      v1[:show] = count_queries do
        get("/solution/categories/#{category_id}/folders/#{folder_id}/articles/#{ids[0]}.json", nil, @headers)
        assert_response 200
      end
      v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
        get("/api/v2/solutions/articles/#{ids[1]}", nil, @headers)
        assert_response 200
      end

      # index
      v1[:index] = count_queries do
        get("/solution/categories/#{category_id}/folders/#{folder_id}.json", nil, @headers)
        assert_response 200
      end
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get("/api/v2/solutions/folders/#{folder_id}/articles", nil, @headers)
        assert_response 200
      end

      # destroy
      v1[:destroy] = count_queries do
        delete("/solution/categories/#{category_id}/folders/#{folder_id}/articles/#{ids[0]}.json", nil, @headers)
        assert_response 200
      end
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/v2/solutions/articles/#{ids[1]}", nil, @headers)
        assert_response 204
      end

      write_to_file(v1, v2)

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        assert v2[key] <= v1[key]
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
