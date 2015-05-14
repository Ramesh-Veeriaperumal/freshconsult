require_relative '../../test_helper'

module ApiDiscussions
  class PostsControllerTest < ActionController::TestCase

    def wrap_cname params
      {:post => params}
    end

    def post_obj
      Post.first
    end
   
    def test_update
      post = quick_create_post
      put :update, construct_params({:id => post.id}, {:body_html => "test reply 2", :answer => 1})
      assert_response :success
      match_json(post_pattern({:body_html => "test reply 2", :answer => true}, post.reload)) 
    end

    def test_update_invalid_answer
      post = post_obj
      put :update, construct_params({:id => post}, {:body_html => "test reply 2", :answer => 90})
      assert_response :bad_request
      match_json([bad_request_error_pattern("answer", "is not included in the list", {:list => ""})])
    end

    def test_update_with_user_id
      post =  post_obj
      put :update, construct_params({:id => post}, {:body_html => "test reply 2", :user_id => User.first})
      assert_response :bad_request
      match_json([bad_request_error_pattern("user_id", "invalid_field")])
    end

    def test_update_with_topic_id
      post =  post_obj
      put :update, construct_params({:id => post}, {:body_html => "test reply 2", :topic_id => Topic.first})
      assert_response :bad_request
      match_json([bad_request_error_pattern("topic_id", "invalid_field")])
    end

    def test_destroy
      post = quick_create_post
      delete :destroy, construct_params({:id => post.id})
      assert_equal " ", @response.body
      assert_response :no_content
      assert_nil Post.find_by_id(post.id)
    end

    def test_destroy_invalid_id
      delete :destroy, construct_params({:id => (1000 + Random.rand(11))})
      assert_equal " ", @response.body
      assert_response :not_found
    end
  end
end