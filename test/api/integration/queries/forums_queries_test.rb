require_relative '../../test_helper'

class ForumsQueriesTest < ActionDispatch::IntegrationTest
  include DiscussionsTestHelper

  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      api_create: 7,
      api_show: 2,
      api_update: 7,
      api_destroy: 12,
      api_follow: 8,
      api_unfollow: 7,
      api_is_following: 2,
      api_topics: 3,

      create: 17,
      show: 11,
      update: 17,
      destroy: 24,
      follow: 18,
      unfollow: 18,
      is_following: 10,
      topics: 12
    }

    category_id = ForumCategory.first.id

    # create
    v1[:create] = count_queries do
      post('/discussions/forums.json', v1_forum_payload, @write_headers)
      assert_response 201
    end
    v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
      post("/api/discussions/categories/#{category_id}/forums", v2_forum_payload, @write_headers)
      assert_response 201
    end

    id1 = Forum.last(2).first.id
    id2 = Forum.last.id

    # show
    v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
      get("/api/discussions/forums/#{id1}", nil, @headers)
      assert_response 200
    end
    v1[:show] = count_queries do
      get("/discussions/forums/#{id2}.json", nil, @headers)
      assert_response 200
    end
    # topics
    v2[:topics], v2[:api_topics], v2[:topics_queries] = count_api_queries do
      get("/api/discussions/forums/#{id1}/topics", nil, @headers)
      assert_response 200
    end
    v1[:topics] = count_queries do
      get("/discussions/forums/#{id2}.json", nil, @headers)
      assert_response 200
    end
    # there is no topics method in v1

    # update
    v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
      put("/api/discussions/forums/#{id1}", v2_update_forum_payload, @write_headers)
      assert_response 200
    end

    v1[:update] = count_queries do
      put("/discussions/forums/#{id2}.json", v1_forum_payload, @write_headers)
      assert_response 200
    end

    Monitorship.where(monitorable_type: 'Forum', monitorable_id: [id1, id2]).update_all(active: false)

    # follow
    v2[:follow], v2[:api_follow], v2[:follow_queries] = count_api_queries do
      post("/api/discussions/forums/#{id1}/follow", nil, @write_headers)
      assert_response 204
    end
    v1[:follow] = count_queries do
      post("/discussions/forum/#{id2}/subscriptions/follow.json", nil, @write_headers)
      assert_response 200
    end

    # is_following
    v2[:is_following], v2[:api_is_following], v2[:is_following_queries] = count_api_queries do
      get("/api/discussions/forums/#{id1}/follow", nil, @headers)
      assert_response 204
    end
    v1[:is_following] = count_queries do
      get("/discussions/forum/#{id2}/subscriptions/is_following.json", nil, @headers)
      assert_response 200
    end

    v2[:is_following] -= 1 # trusted_ip

    # unfollow
    v2[:unfollow], v2[:api_unfollow], v2[:unfollow_queries] = count_api_queries do
      delete("/api/discussions/forums/#{id1}/follow", nil, @headers)
      assert_response 204
    end
    v1[:unfollow] = count_queries do
      post("/discussions/forum/#{id2}/subscriptions/unfollow.json", nil, @write_headers)
      assert_response 200
    end

    # destroy
    v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
      delete("/api/discussions/forums/#{id1}", nil, @headers)
      assert_response 204
    end
    v1[:destroy] = count_queries do
      delete("/discussions/forums/#{id2}.json", nil, @headers)
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
