require_relative '../../test_helper'

class ApiDiscussionsFlowTest < ActionDispatch::IntegrationTest
  include Helpers::DiscussionsHelper
  def fc
    ForumCategory.last || create_test_category
  end

  def f
    Forum.last || create_test_forum(fc)
  end

  def t
    Topic.last || create_test_topic(f)
  end

  def p
    Post.last || create_test_post(t)
  end

  def test_create_post_in_a_new_category
    skip_bullet do
      assert_difference 'ForumCategory.count', 1 do
        post '/api/discussions/categories', v2_category_payload, @write_headers
        assert_response :created
      end
      assert_difference 'Forum.count', 1 do
        post "/api/discussions/categories/#{fc.id}/forums", v2_forum_payload(fc), @write_headers
        assert_response :created
      end

      assert_equal fc.id, f.forum_category_id
      assert_difference 'Topic.count', 1 do
        post "/api/discussions/forums/#{f.id}/topics", v2_topics_payload(f), @write_headers
        assert_response :created
      end

      assert_equal f.id, t.forum_id
      assert_difference 'Post.count', 1 do
        post "/api/discussions/topics/#{t.id}/posts", v2_post_payload(t), @write_headers
        assert_response :created
      end
      assert_equal t.id, p.topic_id
    end
  end

  def test_delete_category_deletes_dependents
    assert_difference 'ForumCategory.count', -1 do
      assert_difference 'Forum.count', -1 do
        assert_difference 'Topic.count', -1 do
          assert_difference 'Post.count', -2 do
            delete "/api/discussions/categories/#{fc.id}", nil, @write_headers
            assert_response :no_content
          end
        end
      end
    end
  end

  def test_change_forum_of_topic
    forum = f
    other_forum = create_test_forum(fc)
    other_forum.update_column(:forum_type, 2)
    posts_count = forum.posts_count
    topics_count = forum.topics_count
    forum.topics.each do |topic|
      skip_bullet do
        put "/api/discussions/topics/#{topic.id}", { forum_id: other_forum.id }.to_json, @write_headers
      end
      assert_response :success
    end
    forum.reload
    other_forum.reload
    assert_equal 0, forum.posts_count + forum.topics_count
    assert_equal posts_count, other_forum.posts_count
    assert_equal topics_count, other_forum.topics_count
    assert_equal [], other_forum.topics.map(&:stamp_type).compact
  end

  def test_monitorships
    topic = t
    user = user_without_monitorships
    get "/api/discussions/topics/followed_by?user_id=#{user.id}", nil, @headers
    assert_response :success
    assert_equal '[]', response.body
    post "/api/discussions/topics/#{topic.id}/follow", { user_id: user.id }.to_json, @write_headers
    assert_response :no_content
    get "/api/discussions/topics/followed_by?user_id=#{user.id}", nil, @headers
    assert_response :success
    match_json [topic_pattern(topic)]
    get "/api/discussions/topics/#{topic.id}/follow?user_id=#{user.id}", nil, @headers
    assert_response :no_content
    delete "/api/discussions/topics/#{topic.id}/follow", { user_id: user.id }.to_json, @write_headers
    assert_response :no_content
    get "/api/discussions/topics/followed_by?user_id=#{user.id}", nil, @headers
    assert_response :success
    assert_equal '[]', response.body
  end
end
