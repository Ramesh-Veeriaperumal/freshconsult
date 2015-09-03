require_relative '../../test_helper'

class ForumsIntegrationest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      api_create: 7,
      api_show: 1,
      api_update: 7,
      api_destroy: 12,
      api_follow: 8,
      api_unfollow: 7,
      api_is_following: 1,
      api_topics: 2,

      create: 20,
      show: 12,
      update: 20,
      destroy: 27,
      follow: 20,
      unfollow: 20,
      is_following: 13,
      topics: 14
    }

    category_id = ForumCategory.first.id

    # create
    v1[:create] = count_queries { post('/discussions/forums.json', v1_forum_payload, @write_headers) }
    v2[:create], v2[:api_create] = count_api_queries do 
      post("/api/discussions/categories/#{category_id}/forums", v2_forum_payload, @write_headers) 
      assert_response :created
    end

    id1 = Forum.last(2).first.id
    id2 = Forum.last.id

    # show
    v2[:show], v2[:api_show] = count_api_queries do 
      get("/api/discussions/forums/#{id1}", nil, @headers) 
      assert_response :success
    end
    v1[:show] = count_queries do  
      get("/discussions/forums/#{id2}.json", nil, @headers)
      assert_response :success
    end
    # topics
    v2[:topics], v2[:api_topics] = count_api_queries do 
      get("/api/discussions/forums/#{id1}/topics", nil, @headers) 
      assert_response :success
    end
    v1[:topics] = count_queries do 
      get("/discussions/forums/#{id2}.json", nil, @headers) 
      assert_response :success
    end
    # there is no topics method in v1

    # update
    v2[:update], v2[:api_update] = count_api_queries do 
      put("/api/discussions/forums/#{id1}", v2_update_forum_payload, @write_headers) 
      assert_response :success
    end

    v1[:update] = count_queries do 
      put("/discussions/forums/#{id2}.json", v1_forum_payload, @write_headers)
      assert_response :success
    end

    Monitorship.update_all({ active: false }, monitorable_type: 'Forum', monitorable_id: [id1, id2])

    # follow
    v2[:follow], v2[:api_follow] = count_api_queries do 
      post("/api/discussions/forums/#{id1}/follow", nil, @write_headers) 
      assert_response :no_content
    end
    v1[:follow] = count_queries { post("/discussions/forum/#{id2}/subscriptions/follow.json", nil, @write_headers) }

    
    # is_following
    v2[:is_following], v2[:api_is_following] = count_api_queries do 
      get("/api/discussions/forums/#{id1}/follow", nil, @headers) 
      assert_response :no_content
    end
    v1[:is_following] = count_queries { get("/discussions/forum/#{id2}/subscriptions/is_following.json", nil, @headers) }


    # unfollow
    v2[:unfollow], v2[:api_unfollow] = count_api_queries do 
      delete("/api/discussions/forums/#{id1}/follow", nil, @write_headers) 
      assert_response :no_content
    end
    v1[:unfollow] = count_queries { post("/discussions/forum/#{id2}/subscriptions/unfollow.json", nil, @write_headers) }

    # destroy
    v2[:destroy], v2[:api_destroy] = count_api_queries do 
      delete("/api/discussions/forums/#{id1}", nil, @headers) 
      assert_response :no_content
    end
    v1[:destroy] = count_queries { delete("/discussions/forums/#{id2}.json", nil, @headers) }

    p v1
    p v2

    v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
      end

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert v2[key] <= v1[key]
      assert_equal v2_expected[api_key], v2[api_key]
      assert_equal v2_expected[key], v2[key]
    end
  end
end
