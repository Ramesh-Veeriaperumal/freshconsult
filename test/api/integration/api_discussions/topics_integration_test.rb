require_relative '../../test_helper'

class TopicsIntegrationest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      create: 8,
      show: 4,
      update: 13,
      destroy: 12,
      follow: 8,
      unfollow: 9,
      is_following: 3,
      posts: 4
    }

    path = '/discussions/topics.json'
    api_path = '/api/discussions/topics'

    # create
    v1[:create] = count_queries { post(path, v1_topics_payload, @write_headers) }
    v2[:create], v2[:api_create] = count_api_queries { post(api_path, v2_topics_payload, @write_headers) }

    id1 = Topic.last(2).first.id
    id2 = Topic.last.id
    id_path = "/discussions/topics/#{id2}.json"
    api_id_path = "/api/discussions/topics/#{id1}"
    api_follow_path = "/api/discussions/topics/#{id1}/follow"

    # show
    v1[:show] = count_queries { get(id_path, nil, @headers) }
    v2[:show], v2[:api_show] = count_api_queries { get(api_id_path, nil, @headers) }

    # posts
    v1[:posts] = count_queries { get(id_path, nil, @headers) }
    v2[:posts], v2[:api_posts] = count_api_queries { get(api_id_path + '/posts', nil, @headers) }
    # there is no posts method in v1

    # update
    v1[:update] = count_queries { put(id_path, v1_topics_payload, @write_headers) }
    v2[:update], v2[:api_update] = count_api_queries { put(api_id_path, v2_topics_payload, @write_headers) }

    # follow
    v1[:follow] = count_queries { post("/discussions/topic/#{id2}/subscriptions/follow.json", nil, @write_headers) }
    v2[:follow], v2[:api_follow] = count_api_queries { post(api_follow_path, nil, @write_headers) }

    # unfollow
    v1[:unfollow] = count_queries { post("/discussions/topic/#{id2}/subscriptions/unfollow.json", nil, @write_headers) }
    v2[:unfollow], v2[:api_unfollow] = count_api_queries { delete(api_follow_path, nil, @write_headers) }

    # is_following
    v1[:is_following] = count_queries { get("/discussions/topic/#{id2}/subscriptions/is_following.json", nil, @headers) }
    v2[:is_following], v2[:api_is_following] = count_api_queries { get(api_follow_path, nil, @headers) }

    # destroy
    v1[:destroy] = count_queries { delete(id_path, nil, @headers) }
    v2[:destroy], v2[:api_destroy] = count_api_queries { delete(api_id_path, nil, @headers) }

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert v2[key] <= v1[key]
      assert_equal v2_expected[key], v2[api_key]
    end
  end
end
