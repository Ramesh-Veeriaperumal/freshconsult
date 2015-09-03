require_relative '../../test_helper'

class TopicsIntegrationTest < ActionDispatch::IntegrationTest
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

        create: 46,
        show: 12,
        update: 34,
        destroy: 28,
        follow: 14,
        unfollow: 21,
        is_following: 13,
        posts: 14
      }

      forum_id = create_test_forum(ForumCategory.first).id
      api_forum_id = create_test_forum(ForumCategory.first).id
      path = '/discussions/topics.json'
      api_path = "/api/discussions/forums/#{api_forum_id}/topics"

      # create
      v1[:create] = count_queries { post(path, v1_topics_payload(forum_id), @write_headers) }
      v2[:create], v2[:api_create] = count_api_queries do 
        post(api_path, v2_topics_payload, @write_headers) 
        assert_response :created
      end

      id1 = Topic.where(forum_id: forum_id).first.id
      id2 = Topic.where(forum_id: api_forum_id).first.id
      id_path = "/discussions/topics/#{id2}.json"
      api_id_path = "/api/discussions/topics/#{id1}"
      api_follow_path = "/api/discussions/topics/#{id1}/follow"

      # show
      v1[:show] = count_queries { get(id_path, nil, @headers) }
      v2[:show], v2[:api_show] = count_api_queries do
        get(api_id_path, nil, @headers) 
        assert_response :success
      end

      # posts
      v1[:posts] = count_queries { get(id_path, nil, @headers) }
      v2[:posts], v2[:api_posts] = count_api_queries do
        get(api_id_path + '/posts', nil, @headers) 
        assert_response :success
      end
      # there is no posts method in v1

      # update
      v1[:update] = count_queries { put(id_path, v1_topics_payload(forum_id), @write_headers) }
      v2[:update], v2[:api_update] = count_api_queries do 
        put(api_id_path, v2_update_topics_payload, @write_headers) 
        assert_response :success
      end

      # follow
      v1[:follow] = count_queries { post("/discussions/topic/#{id2}/subscriptions/follow.json", nil, @write_headers) }
      v2[:follow], v2[:api_follow] = count_api_queries do 
        post(api_follow_path, nil, @write_headers) 
        assert_response :no_content
      end

      # is_following
      v1[:is_following] = count_queries { get("/discussions/topic/#{id2}/subscriptions/is_following.json", nil, @headers) }
      v2[:is_following], v2[:api_is_following] = count_api_queries do 
        get(api_follow_path, nil, @headers) 
        assert_response :no_content 
      end

      # unfollow
      v1[:unfollow] = count_queries { post("/discussions/topic/#{id2}/subscriptions/unfollow.json", nil, @write_headers) }
      v2[:unfollow], v2[:api_unfollow] = count_api_queries do 
        delete(api_follow_path, nil, @write_headers)  
        assert_response :no_content
      end

      # destroy
      v1[:destroy] = count_queries { delete(id_path, nil, @headers) }
      v2[:destroy], v2[:api_destroy] = count_api_queries do 
        delete(api_id_path, nil, @headers) 
        assert_response :no_content 
      end

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
end
