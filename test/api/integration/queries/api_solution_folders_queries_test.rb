require_relative '../../test_helper'

class ApiSolutionFolderQueriesTest < ActionDispatch::IntegrationTest
  include SolutionsTestHelper

  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 4,
        api_update: 3,
        api_show: 3,
        api_index: 7,
        api_destroy: 11,

        create: 24,
        update: 19,
        show: 13,
        index: 17,
        destroy: 23,
      }

      category_id = @account.solution_category_meta.where(is_default: false).first.id

      # create
      v1[:create] = count_queries do
        post("/solution/categories/#{category_id}/folders.json", v1_folder_payload, @write_headers)
        assert_response 200
      end
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post("/api/v2/solutions/categories/#{category_id}/folders", v2_folder_payload, @write_headers)
        assert_response 201
      end

      # Query in create.json.api
      v2[:create] -= 1

      ids = Solution::FolderMeta.last(2).map(&:id).sort

      # # update
      v1[:update] = count_queries do
        put("/solution/categories/#{category_id}/folders/#{ids[0]}.json", v1_folder_payload, @write_headers)
        assert_response 200
      end
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/v2/solutions/folders/#{ids[1]}", v2_folder_payload, @write_headers)
        assert_response 200
      end

      # show
      v1[:show] = count_queries do
        get("/solution/categories/#{category_id}/folders/#{ids[0]}.json", nil, @headers)
        assert_response 200
      end
      v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
        get("/api/v2/solutions/folders/#{ids[1]}", nil, @headers)
        assert_response 200
      end

      # index
      v1[:index] = count_queries do
        get("/solution/categories/#{category_id}.json", nil, @headers)
        assert_response 200
      end
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get("/api/v2/solutions/categories/#{category_id}/folders", nil, @headers)
        assert_response 200
      end

      # destroy
      v1[:destroy] = count_queries do
        delete("/solution/categories/#{category_id}/folders/#{ids[0]}.json", nil, @headers)
        assert_response 200
      end
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/v2/solutions/folders/#{ids[1]}", nil, @headers)
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
