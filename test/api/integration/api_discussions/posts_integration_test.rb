require_relative '../../test_helper'

class PostsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 5,
        api_update: 6,
        api_destroy: 9,

        create: 35,
        update: 18,
        destroy: 30
      }

      t = create_test_topic(create_test_forum(ForumCategory.first))
      topic_id = create_test_topic(create_test_forum(ForumCategory.first)).id

      # create
      v1[:create] = count_queries { post("/discussions/topics/#{t.id}/posts.json", v1_post_payload(t), @write_headers) }
      v2[:create], v2[:api_create] = count_api_queries do 
        post("/api/discussions/topics/#{topic_id}/posts", v2_post_payload(t), @write_headers) 
        assert_response :created
      end

      id2 = Post.where(topic_id: t.id).first.id
      id1 = Post.where(topic_id: topic_id).first.id

      # update
      v1[:update] = count_queries { put("/discussions/topics/#{t.id}/posts/#{id2}.json", v1_post_payload(t), @write_headers) }
      v2[:update], v2[:api_update] = count_api_queries do 
        put("/api/discussions/posts/#{id1}", v2_post_payload(t), @write_headers) 
        assert_response :success
      end


      # destroy
      v1[:destroy] = count_queries { delete("/discussions/topics/#{t.id}/posts/#{id2}.json", nil, @headers) }
      v2[:destroy], v2[:api_destroy] = count_api_queries do 
        delete("/api/discussions/posts/#{id1}", nil, @headers) 
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
