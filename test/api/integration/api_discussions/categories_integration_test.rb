require_relative '../../test_helper'

class CategoriesIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::DiscussionsTestHelper

  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      api_create: 8,
      api_show: 1,
      api_update: 6,
      api_index: 1,
      api_destroy: 8,
      api_forums: 2,

      create: 20,
      show: 12,
      update: 17,
      index: 12,
      destroy: 20,
      forums: 13
    }

    # create
    v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
      post('/api/discussions/categories', v2_category_payload, @write_headers)
      assert_response 201
    end
    v1[:create] = count_queries do
      post('/discussions/categories.json', v1_category_payload, @write_headers)
      assert_response 201
    end

    id1 = ForumCategory.last(2).first.id
    id2 = ForumCategory.last.id

    # show
    v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
      get("/api/discussions/categories/#{id1}", nil, @headers)
      assert_response 200
    end
    v1[:show] = count_queries do
      get("/discussions/categories/#{id2}.json", nil, @headers)
      assert_response 200
    end

    # forums
    v2[:forums], v2[:api_forums], v2[:forums_queries] = count_api_queries do
      get("/api/discussions/categories/#{id1}/forums", nil, @headers)
      assert_response 200
    end
    v1[:forums] = count_queries do
      get("/discussions/categories/#{id2}.json", nil, @headers)
      assert_response 200
    end
    # there is no forums method in v1

    # update
    v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
      put("/api/discussions/categories/#{id1}", v2_category_payload, @write_headers)
      assert_response 200
    end
    v1[:update] = count_queries do
      put("/discussions/categories/#{id2}.json", v1_category_payload, @write_headers)
      assert_response 200
    end

    # index
    v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
      get('/api/discussions/categories', nil, @headers)
      assert_response 200
    end
    v1[:index] = count_queries do
      get('/discussions/categories.json', nil, @headers)
      assert_response 200
    end

    # destroy
    v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
      delete("/api/discussions/categories/#{id1}", nil, @headers)
      assert_response 204
    end
    v1[:destroy] = count_queries do
      delete("/discussions/categories/#{id2}.json", nil, @headers)
      assert_response 200
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
