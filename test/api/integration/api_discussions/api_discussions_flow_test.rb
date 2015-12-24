require_relative '../../test_helper'

class ApiDiscussionsFlowTest < ActionDispatch::IntegrationTest
  include Helpers::DiscussionsTestHelper
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

  JSON_ROUTES = Rails.application.routes.routes.select do |r|
    r.path.spec.to_s.starts_with('/api/discussions/') &&
    ['post', 'put'].include?(r.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase)
  end.collect do |x|
    [
      x.path.spec.to_s.gsub('(.:format)', ''),
      x.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase
    ]
  end.to_h

  JSON_ROUTES.each do |path, verb|
    define_method("test_#{path}_#{verb}_with_multipart") do
      headers, params = encode_multipart(category_params)
      skip_bullet do
        send(verb.to_sym, path, params, @write_headers.merge(headers))
      end
      assert_response 415
      response.body.must_match_json_expression(un_supported_media_type_error_pattern)
    end
  end

  def test_create_post_in_a_new_category
    skip_bullet do
      assert_difference 'ForumCategory.count', 1 do
        post '/api/discussions/categories', v2_category_payload, @write_headers
        assert_response 201
      end
      assert_difference 'Forum.count', 1 do
        post "/api/discussions/categories/#{fc.id}/forums", v2_forum_payload(fc), @write_headers
        assert_response 201
      end

      assert_equal fc.id, f.forum_category_id
      assert_difference 'Topic.count', 1 do
        post "/api/discussions/forums/#{f.id}/topics", v2_topics_payload(f), @write_headers
        assert_response 201
      end

      assert_equal f.id, t.forum_id
      assert_difference 'Post.count', 1 do
        post "/api/discussions/topics/#{t.id}/comments", v2_post_payload(t), @write_headers
        assert_response 201
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
            assert_response 204
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
      assert_response 200
    end
    forum.reload
    other_forum.reload
    assert_equal 0, forum.posts_count + forum.topics_count
    assert_equal posts_count, other_forum.posts_count
    assert_equal topics_count, other_forum.topics_count
    assert_equal [], other_forum.topics.map(&:stamp_type).compact
  end

  def test_empty_array_for_company_ids
    company_ids = create_company.id
    params_hash = forum_params.merge(company_ids: [company_ids], forum_visibility: 4)
    post "/api/discussions/categories/#{fc.id}/forums", params_hash.to_json, @write_headers
    forum = Forum.find_by_name(params_hash[:name])
    assert_response 201
    assert forum.customer_forums.count == 1

    put "/api/discussions/forums/#{forum.id}", { company_ids: nil }.to_json, @write_headers
    match_json([bad_request_error_pattern('company_ids', :data_type_mismatch, data_type: 'Array')])
    assert_response 400

    put "/api/discussions/forums/#{forum.id}", { company_ids: [] }.to_json, @write_headers
    assert_response 200
    assert forum.reload.customer_forums.count == 0
  end

  def test_monitorships
    topic = t
    user = user_without_monitorships
    get "/api/discussions/topics/followed_by?user_id=#{user.id}", nil, @headers
    assert_response 200
    assert_equal '[]', response.body
    post "/api/discussions/topics/#{topic.id}/follow", { user_id: user.id }.to_json, @write_headers
    assert_response 204
    get "/api/discussions/topics/followed_by?user_id=#{user.id}", nil, @headers
    assert_response 200
    match_json [topic_pattern(topic)]
    get "/api/discussions/topics/#{topic.id}/follow?user_id=#{user.id}", nil, @headers
    assert_response 204
    delete "/api/discussions/topics/#{topic.id}/follow?user_id=#{user.id}", nil, @headers
    assert_response 204
    get "/api/discussions/topics/followed_by?user_id=#{user.id}", nil, @headers
    assert_response 200
    assert_equal '[]', response.body
  end
end
