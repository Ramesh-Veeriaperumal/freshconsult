require_relative '../../../test_helper'

module ApiDiscussions
  class Pipe::ApiCommentsControllerTest < ActionController::TestCase
    include DiscussionsTestHelper

    def wrap_cname(params)
      { api_comment: params }
    end

    def user
      user = User.first
      user
    end

    def forum_obj
      Forum.first
    end

    def topic_obj
      Topic.first || create_test_topic(forum_obj)
    end

    def create_comment_params_hash
      body = Faker::Lorem.paragraph
      params_hash = { body: body }
      params_hash
    end

    def test_create_with_created_at_updated_at_user_id
      created_at = updated_at = Time.now
      params_hash = create_comment_params_hash.merge('created_at' => created_at,
                                                  'updated_at' => updated_at,
                                                  'user_id' => user.id)
      post :create, construct_params({ version: 'private', id: topic_obj.id }, params_hash)
      assert_response 201
      comment = Post.last
      match_json(comment_pattern(params_hash, comment))
      match_json(comment_pattern({}, comment))
      assert (comment.created_at - created_at).to_i == 0
      assert (comment.updated_at - updated_at).to_i == 0
      assert_equal comment.user_id, user.id
    end

    def test_create_with_user_id
      params_hash = create_comment_params_hash.merge('user_id' => user.id)
      post :create, construct_params({ version: 'private', id: topic_obj.id }, params_hash)
      assert_response 201
      comment = Post.last
      match_json(comment_pattern(params_hash, comment))
      match_json(comment_pattern({}, comment))
      assert_equal comment.user_id, user.id
    end

    def test_create_without_user_id
      post :create, construct_params({ version: 'private', id: topic_obj.id }, create_comment_params_hash)
      match_json([bad_request_error_pattern('user_id', :datatype_mismatch, code: :missing_field, expected_data_type: Integer)])
      assert_response 400
    end
  end
end