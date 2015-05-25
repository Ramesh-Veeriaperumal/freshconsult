require_relative '../../test_helper'

class PostsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      create: 6,
      update: 3,
      destroy: 9
    }
    t = Topic.first

    # create
    v1[:create] = count_queries { post("/discussions/topics/#{t.id}/posts.json", v1_post_payload(t), @write_headers) }
    v2[:create], v2[:api_create] = count_api_queries { post('/api/discussions/posts', v2_post_payload(t), @write_headers) }

    id1 = Post.last(2).first.id
    id2 = Post.last.id

    # update
    v1[:update] = count_queries { put("/discussions/topics/#{t.id}/posts/#{id2}.json", v1_post_payload(t), @write_headers) }
    v2[:update], v2[:api_update] = count_api_queries { put("/api/discussions/posts/#{id1}", v2_post_payload(t), @write_headers) }

    # destroy
    v1[:destroy] = count_queries { delete("/discussions/topics/#{t.id}/posts/#{id2}.json", nil, @headers) }
    v2[:destroy], v2[:api_destroy] = count_api_queries { delete("/api/discussions/posts/#{id1}", nil, @headers) }

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert v2[key] <= v1[key]
      assert_equal v2_expected[key], v2[api_key]
    end
  end
end
