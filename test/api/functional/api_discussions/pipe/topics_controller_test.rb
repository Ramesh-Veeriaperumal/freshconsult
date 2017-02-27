require_relative '../../../test_helper'

module ApiDiscussions
  class Pipe::TopicsControllerTest < ActionController::TestCase
    include DiscussionsTestHelper

    def wrap_cname(params)
      { topic: params }
    end

    def user
      user = User.first
      user
    end

    def forum_obj
      Forum.first
    end

    def create_topic_params_hash
      message = Faker::Lorem.paragraph
      locked = true
      sticky = false
      title = 'Test topic'
      params_hash = { message: message, locked: locked, sticky: sticky, title: title}
      params_hash
    end

    def test_create_with_created_at_updated_at_user_id
      created_at = updated_at = Time.now
      params_hash = create_topic_params_hash.merge('created_at' => created_at,
                                                  'updated_at' => updated_at,
                                                  'user_id' => user.id)
      post :create, construct_params({ version: 'private', id: forum_obj.id }, params_hash)
      Rails.logger.debug @response.inspect
      
      assert_response 201
      topic = Topic.last
      match_json(topic_pattern(params_hash, topic))
      match_json(topic_pattern({}, topic))
      assert (topic.created_at - created_at).to_i == 0
      assert (topic.updated_at - updated_at).to_i == 0
      assert (topic.posts.last.created_at - created_at).to_i == 0
      assert (topic.posts.last.updated_at - updated_at).to_i == 0
      assert_equal topic.user_id, user.id
    end

    def test_create_with_user_id
      params_hash = create_topic_params_hash.merge('user_id' => user.id)
      post :create, construct_params({ version: 'private', id: forum_obj.id }, params_hash)
      assert_response 201
      topic = Topic.last
      match_json(topic_pattern(params_hash, topic))
      match_json(topic_pattern({}, topic))
      assert_equal topic.user_id, user.id
    end

    def test_create_without_user_id
      post :create, construct_params({ version: 'private', id: forum_obj.id }, create_topic_params_hash)
      expected = {
        description: "Validation failed",
        errors: [
          {
            field: "user_id",
            message: "It should be a/an Positive Integer",
            code: "missing_field"
          }
        ]
      }
      match_json(expected)
      assert_response 400
    end
  end
end
