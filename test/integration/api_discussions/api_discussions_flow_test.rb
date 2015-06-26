# require_relative '../../test_helper'

# class ApiDiscussionsFlowTest < ActionDispatch::IntegrationTest
#   def fc
#     ForumCategory.last
#   end

#   def f
#     Forum.last
#   end

#   def t
#     Topic.last
#   end

#   def p
#     Post.last
#   end

#   def test_create_post_in_a_new_category
#     assert_difference 'ForumCategory.count', 1 do
#       post '/api/discussions/categories', v2_category_payload, @headers
#     end
#     assert_difference 'Forum.count', 1 do
#       post '/api/discussions/forums', v2_forum_payload(fc), @headers
#     end

#     assert_equal fc.id, f.forum_category_id
#     assert_difference 'Topic.count', 1 do
#       post '/api/discussions/topics', v2_topics_payload(f), @headers
#     end

#     assert_equal f.id, t.forum_id
#     assert_difference 'Post.count', 1 do
#       post '/api/discussions/posts', v2_post_payload(t), @headers
#     end
#     assert_equal t.id, p.topic_id
#   end

#   def test_delete_category_deletes_dependents
#     assert_difference 'ForumCategory.count', -1 do
#       assert_difference 'Forum.count', -1 do
#         assert_difference 'Topic.count', -1 do
#           assert_difference 'Post.count', -1 do
#             delete "/api/discussions/categories/#{fc.id}", nil, @headers
#           end
#         end
#       end
#     end
#   end

#   def test_change_forum_type_of_forum
#     forum = f
#     assert_not_equal 7, topic.stamp_type
#     put "/api/discussions/forums/#{forum.id}", { forum_type: 2 }.to_json, @headers
#     assert_equal 7, topic.stamp_type
#   end

#   def test_change_forum_of_topic
#     topic = t
#     forum = f
#     other_forum = Forum.first
#     assert_equal 0, other_forum.posts_count + other_forum.topics_count
#     assert_not_equal forum, other_forum
#     put "/api/discussions/topics/#{topic.id}", { forum_id: other_forum.id }.to_json, @headers
#     assert_equal 0, forum.posts_count + forum.topics_count
#     assert_not_equal 0, other_forum.posts_count
#     assert_not_equal 0, other_forum.topics_count
#   end
# end
