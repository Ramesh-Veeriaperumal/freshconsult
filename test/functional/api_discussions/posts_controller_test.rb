require_relative '../../test_helper'

module ApiDiscussions
  class PostsControllerTest < ActionController::TestCase
   
    def test_update
      post = Post.first || create_test_post(Topic.first, current_user)
      put :update, :version => "v2", :format=> :json, :id => post.id, :post => {:body_html => "test reply 2", :answer => 1}
      assert_response :success
      response.body.must_match_json_expression(post_pattern({:body_html => "test reply 2", :answer => true}, post.reload)) 
    end

    def test_update_invalid_answer
      put :update, :version => "v2", :format=> :json, :id => Post.first.id, :post => {:body_html => "test reply 2", :answer => 90}
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("answer", "is not included in the list", {:list => ""})])
    end

    def test_update_with_user_id
      put :update, :version => "v2", :format=> :json, :id => Post.first.id, :post => {:body_html => "test reply 2", :user_id => User.first}
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("user_id", "invalid_field")])
    end

    def test_update_with_topic_id
      put :update, :version => "v2", :format=> :json, :id => Post.first.id, :post => {:body_html => "test reply 2", :topic_id => Topic.first}
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("topic_id", "invalid_field")])
    end

    def test_destroy
      post = Post.first || create_test_post(Topic.first, current_user)
      delete :destroy, :version => "v2", :format => :json, :id => post.id
      assert_equal " ", @response.body
      assert_response :no_content
      assert_nil Post.find_by_id(post.id)
    end

    def test_destroy_invalid_id
      delete :destroy, :version => "v2", :format => :json, :id => (1000 + Random.rand(11))
      assert_equal " ", @response.body
      assert_response :not_found
    end
  end
end