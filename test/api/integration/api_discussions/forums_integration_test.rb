require_relative '../../test_helper'

class ForumsIntegrationest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      create: 9,
      show: 4,
      update: 9,
      destroy: 13,
      follow: 9,
      unfollow: 9,
      is_following: 3,
      topics: 4
    }

    # create
    v1[:create] = count_queries { post('/discussions/forums.json', v1_forum_payload, @write_headers) }
    v2[:create], v2[:api_create] = count_api_queries { post('/api/discussions/forums', v2_forum_payload, @write_headers) }

    id1 = Forum.last(2).first.id
    id2 = Forum.last.id

    # show
    v2[:show], v2[:api_show] = count_api_queries { get("/api/discussions/forums/#{id1}", nil, @headers) }
    v1[:show] = count_queries { get("/discussions/forums/#{id2}.json", nil, @headers) }

    # topics
    v2[:topics], v2[:api_topics] = count_api_queries { get("/api/discussions/forums/#{id1}/topics", nil, @headers) }
    v1[:topics] = count_queries { get("/discussions/forums/#{id2}.json", nil, @headers) }
    # there is no topics method in v1

    # update
    v2[:update], v2[:api_update] = count_api_queries { put("/api/discussions/forums/#{id1}", v2_forum_payload, @write_headers) }
    v1[:update] = count_queries { put("/discussions/forums/#{id2}.json", v1_forum_payload, @write_headers) }

    # follow
    v2[:follow], v2[:api_follow] = count_api_queries { post("/api/discussions/forums/#{id1}/follow", nil, @write_headers) }
    v1[:follow] = count_queries { post("/discussions/forum/#{id2}/subscriptions/follow.json", nil, @write_headers) }

    # unfollow
    v2[:unfollow], v2[:api_unfollow] = count_api_queries { delete("/api/discussions/forums/#{id1}/follow", nil, @write_headers) }
    v1[:unfollow] = count_queries { post("/discussions/forum/#{id2}/subscriptions/unfollow.json", nil, @write_headers) }

    # is_following
    v2[:is_following], v2[:api_is_following] = count_api_queries { get("/api/discussions/forums/#{id1}/follow", nil, @headers) }
    v1[:is_following] = count_queries { get("/discussions/forum/#{id2}/subscriptions/is_following.json", nil, @headers) }

    # destroy
    v2[:destroy], v2[:api_destroy] = count_api_queries { delete("/api/discussions/forums/#{id1}", nil, @headers) }
    v1[:destroy] = count_queries { delete("/discussions/forums/#{id2}.json", nil, @headers) }

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert v2[key] <= v1[key]
      assert_equal v2_expected[key], v2[api_key]
    end
  end
end
