require_relative '../../test_helper'

class TopicsIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::DiscussionsTestHelper

  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 7,
        api_show: 1,
        api_update: 9,
        api_destroy: 11,
        api_follow: 3,
        api_unfollow: 7,
        api_is_following: 1,
        api_posts: 2,

        create: 45,
        show: 12,
        update: 34,
        destroy: 28,
        follow: 13,
        unfollow: 20,
        is_following: 12,
        posts: 13
      }

      forum_id = create_test_forum(ForumCategory.first).id
      api_forum_id = create_test_forum(ForumCategory.first).id
      path = '/discussions/topics.json'
      api_path = "/api/discussions/forums/#{api_forum_id}/topics"

      # create
      v1[:create] = count_queries do
        post(path, v1_topics_payload(forum_id), @write_headers)
        assert_response 200
      end
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post(api_path, v2_topics_payload, @write_headers)
        assert_response 201
      end

      id1 = Topic.where(forum_id: forum_id).first.id
      id2 = Topic.where(forum_id: api_forum_id).first.id
      id_path = "/discussions/topics/#{id2}.json"
      api_id_path = "/api/discussions/topics/#{id1}"
      api_follow_path = "/api/discussions/topics/#{id1}/follow"

      # show
      v1[:show] = count_queries do
        get(id_path, nil, @headers)
        assert_response 200
      end
      v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
        get(api_id_path, nil, @headers)
        assert_response 200
      end

      # comments
      v1[:posts] = count_queries do
        get(id_path, nil, @headers)
        assert_response 200
      end
      v2[:posts], v2[:api_posts], v2[:posts_queries] = count_api_queries do
        get(api_id_path + '/comments', nil, @headers)
        assert_response 200
      end
      # there is no posts method in v1

      # update
      v1[:update] = count_queries do
        put(id_path, v1_topics_payload(forum_id), @write_headers)
        assert_response 200
      end
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put(api_id_path, v2_update_topics_payload, @write_headers)
        assert_response 200
      end

      # follow
      v1[:follow] = count_queries do
        post("/discussions/topic/#{id2}/subscriptions/follow.json", nil, @write_headers)
        assert_response 200
      end
      v2[:follow], v2[:api_follow], v2[:follow_queries] = count_api_queries do
        post(api_follow_path, nil, @write_headers)
        assert_response 204
      end

      # is_following
      v1[:is_following] = count_queries do
        get("/discussions/topic/#{id2}/subscriptions/is_following.json", nil, @headers)
        assert_response 200
      end
      v2[:is_following], v2[:api_is_following], v2[:is_following_queries] = count_api_queries do
        get(api_follow_path, nil, @headers)
        assert_response 204
      end

      # unfollow
      v1[:unfollow] = count_queries do
        post("/discussions/topic/#{id2}/subscriptions/unfollow.json", nil, @write_headers)
        assert_response 200
      end
      v2[:unfollow], v2[:api_unfollow], v2[:unfollow_queries] = count_api_queries do
        delete(api_follow_path, nil, @headers)
        assert_response 204
      end

      # destroy
      v1[:destroy] = count_queries do
        delete(id_path, nil, @headers)
        assert_response 200
      end
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete(api_id_path, nil, @headers)
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
