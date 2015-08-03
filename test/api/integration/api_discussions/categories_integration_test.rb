require_relative '../../test_helper'

class CategoriesIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      create: 8,
      show: 1,
      update: 6,
      index: 1,
      destroy: 8,
      forums: 2
    }

    # create
    v2[:create], v2[:api_create] = count_api_queries { post('/api/discussions/categories', v2_category_payload, @write_headers) }
    v1[:create] = count_queries { post('/discussions/categories.json', v1_category_payload, @write_headers) }

    id1 = ForumCategory.last(2).first.id
    id2 = ForumCategory.last.id

    # show
    v2[:show], v2[:api_show] = count_api_queries { get("/api/discussions/categories/#{id1}", nil, @headers) }
    v1[:show] = count_queries { get("/discussions/categories/#{id2}.json", nil, @headers) }

    # forums
    v2[:forums], v2[:api_forums] = count_api_queries { get("/api/discussions/categories/#{id1}/forums", nil, @headers) }
    v1[:forums] = count_queries { get("/discussions/categories/#{id2}.json", nil, @headers) }
    # there is no forums method in v1

    # update
    v2[:update], v2[:api_update] = count_api_queries { put("/api/discussions/categories/#{id1}", v2_category_payload, @write_headers) }
    v1[:update] = count_queries { put("/discussions/categories/#{id2}.json", v1_category_payload, @write_headers) }

    # index
    v2[:index], v2[:api_index] = count_api_queries { get('/api/discussions/categories', nil, @headers) }
    v1[:index] = count_queries { get('/discussions/categories.json', nil, @headers) }

    # destroy
    v2[:destroy], v2[:api_destroy] = count_api_queries { delete("/api/discussions/categories/#{id1}", nil, @headers) }
    v1[:destroy] = count_queries { delete("/discussions/categories/#{id2}.json", nil, @headers) }

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
      assert v2[key] <= v1[key]
      assert_equal v2_expected[key], v2[api_key]
    end
  end

  # def test_index_caching
  #   clear_cache
  #   fc = ForumCategory.first
  #   get("/api/discussions/categories", nil, @headers)
  #   db_response = @response.body
  #   cache_key = "jbuilder/forum_categories/#{fc.id}-#{fc.updated_at.utc.to_s(:number)}"
  #   assert_nil Rails.cache.read(cache_key)

  #   with_caching do
  #     get("/api/discussions/categories", nil, @headers)
  #   end
  #   cached_response = @response.body
  #   assert_match Rails.cache.read(cache_key).to_json[0..-2], db_response
  #   assert_match Rails.cache.read(cache_key).to_json[0..-2], cached_response

  #   # added new category
  #   post("/api/discussions/categories", v2_category_payload, @write_headers)
  #   get("/api/discussions/categories", nil, @headers)
  #   db_response = parse_response(@response.body)

  #   with_caching do
  #     get("/api/discussions/categories", nil, @headers)
  #   end
  #   cached_response = parse_response(@response.body)
  #   assert_equal db_response, cached_response

  #   # remove a category
  #   ForumCategory.last.destroy
  #   get("/api/discussions/categories", nil, @headers)
  #   db_response = parse_response(@response.body)

  #   with_caching do
  #     get("/api/discussions/categories", nil, @headers)
  #   end
  #   cached_response = parse_response(@response.body)
  #   assert_equal db_response, cached_response

  #   # save a category
  #   ForumCategory.last.update_attributes(:name => "New Title")
  #   get("/api/discussions/categories", nil, @headers)
  #   db_response = parse_response(@response.body)

  #   with_caching do
  #     get("/api/discussions/categories", nil, @headers)
  #   end
  #   cached_response = parse_response(@response.body)
  #   assert_equal db_response, cached_response
  # end

  # def test_show_caching
  #   clear_cache
  #   fc = ForumCategory.last
  #   cache_key = "jbuilder/forum_categories/#{fc.id}-#{fc.updated_at.utc.to_s(:number)}"
  #   get("/api/discussions/categories/#{fc.id}", nil, @headers)
  #   db_response = @response.body
  #   assert_nil Rails.cache.read(cache_key)

  #   with_caching do
  #     get("/api/discussions/categories/#{fc.id}", nil, @headers)
  #   end
  #   cached_response = parse_response(@response.body)
  #   assert_match Rails.cache.read(cache_key).to_json[0..-2], db_response
  #   assert_equal cached_response, parse_response(db_response)

  #   # save a category
  #   ForumCategory.first.update_attributes(:name => "New Title")
  #   get("/api/discussions/categories/#{fc.id}", nil, @headers)
  #   db_response = parse_response(@response.body)

  #   with_caching do
  #     get("/api/discussions/categories/#{fc.id}", nil, @headers)
  #   end
  #   cached_response = parse_response(@response.body)
  #   assert_equal db_response, cached_response

  #   # delete category
  #   fc.destroy
  #   get("/api/discussions/categories/#{fc.id}", nil, @headers)
  #   db_response = parse_response(@response.body)
  #   with_caching do
  #     get("/api/discussions/categories/#{fc.id}", nil, @headers)
  #   end
  #   cached_response = parse_response(@response.body)
  #   assert_equal db_response, cached_response
  # end
end
