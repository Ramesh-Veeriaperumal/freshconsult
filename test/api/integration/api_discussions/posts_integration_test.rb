require_relative '../../test_helper'

class PostsIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::DiscussionsTestHelper

  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 5,
        api_update: 6,
        api_destroy: 9,

        create: 34,
        update: 17,
        destroy: 30
      }

      t = create_test_topic(create_test_forum(ForumCategory.first))
      topic_id = create_test_topic(create_test_forum(ForumCategory.first)).id

      # create
      v1[:create] = count_queries do
        post("/discussions/topics/#{t.id}/posts.json", v1_post_payload(t), @write_headers)
        assert_response 201
      end
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post("/api/discussions/topics/#{topic_id}/posts", v2_post_payload(t), @write_headers)
        assert_response 201
      end

      id2 = Post.where(topic_id: t.id).first.id
      id1 = Post.where(topic_id: topic_id).first.id

      # update
      v1[:update] = count_queries do
        put("/discussions/topics/#{t.id}/posts/#{id2}.json", v1_post_payload(t), @write_headers)
        assert_response 200
      end
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/discussions/posts/#{id1}", v2_post_payload(t), @write_headers)
        assert_response 200
      end

      # destroy
      v1[:destroy] = count_queries do
        delete("/discussions/topics/#{t.id}/posts/#{id2}.json", nil, @headers)
        assert_response 200
      end
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/discussions/posts/#{id1}", nil, @headers)
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
