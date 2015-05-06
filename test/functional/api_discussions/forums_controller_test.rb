require_relative '../../test_helper'

module ApiDiscussions
  class ForumsControllerTest < ActionController::TestCase
    

    def test_destroy
      fc = ForumCategory.first || create_test_category
      forum = create_test_forum(fc)
      controller.class.any_instance.stubs(:back_up_topic_ids).once
      delete :destroy, :version => "v2", :format => :json, :id => forum.id
      assert_equal " ", @response.body
      assert_response :no_content
      assert_nil Forum.find_by_id(forum.id)
    end

     def test_destroy_invalid_id
      delete :destroy, :version => "v2", :format => :json, :id => (1000 + Random.rand(11))
      assert_equal " ", @response.body
      assert_response :not_found
    end

    def test_update
      fc = ForumCategory.first || create_test_category
      forum = Forum.first || create_test_forum(fc)
      put :update, :version => "v2", :format => :json, :id => forum.id, :forum => {:forum_type => 2}
      assert_response :success
      response.body.must_match_json_expression(forum_pattern(forum.reload))
    end

    def test_update_blank_name
      fc = ForumCategory.first || create_test_category
      forum = Forum.first || create_test_forum(fc)
      put :update, :version => "v2", :format => :json, :id => forum.id, :forum => {:name => " "}
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("name", "can't be blank")])
    end


    def test_update_invalid_forum_type
      fc = ForumCategory.first || create_test_category
      forum = Forum.first || create_test_forum(fc)
      put :update, :version => "v2", :format => :json, :id => forum.id, :forum => {:forum_type => 7897}
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("forum_type", "is not included in the list", {:list => ApiConstants::LIST_FIELDS[:forum_type]})])
    end

    def test_update_invalid_forum_visibility
      fc = ForumCategory.first || create_test_category
      forum = Forum.first || create_test_forum(fc)
      put :update, :version => "v2", :format => :json, :id => forum.id, :forum => {:forum_visibility => 7897}
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("forum_visibility", "is not included in the list", {:list => ApiConstants::LIST_FIELDS[:forum_visibility]})])
    end

     def test_update_duplicate_name
      fc = ForumCategory.first || create_test_category
      forum = Forum.first || create_test_forum(fc)
      another_forum = create_test_forum(fc)
      put :update, :version => "v2", :format => :json, :id => forum.id, :forum => {:name => another_forum.name}
      assert_response :conflict
      response.body.must_match_json_expression([bad_request_error_pattern("name", "already exists in the selected category")])
    end

    def test_update_unexpected_fields
      fc = ForumCategory.first || create_test_category
      forum = Forum.first || create_test_forum(fc)
      another_forum = create_test_forum(fc)
      put :update, :version => "v2", :format => :json, :id => forum.id, :forum => {:junk => another_forum.name}
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("junk", "invalid_field")])
    end

    def test_update_missing_fields
      fc = ForumCategory.first || create_test_category
      forum = Forum.first || create_test_forum(fc)
      put :update, :version => "v2", :format => :json, :id => forum.id, :forum => { }
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("forum", "missing_field")])
    end

    def test_update_invalid_forum_category_id
      fc = ForumCategory.first || create_test_category
      forum = Forum.first || create_test_forum(fc)
      put :update, :version => "v2", :format => :json, :id => forum.id, :forum => {:forum_category_id => 89 }
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("forum_category", "can't be blank")])
    end

    # def test_update_invalid_customer_id
    #   fc = ForumCategory.first || create_test_category
    #   forum = Forum.first || create_test_forum(fc)
    #   put :update, :version => "v2", :format => :json, :id => forum.id, :forum => {:forum_visibility => 4, :customers => "1,67" }
    #   assert_response :bad_request
    #   response.body.must_match_json_expression([bad_request_error_pattern("forum_category_id", "can't be blank")])
    # end

     def test_update_with_customer_id
      fc = ForumCategory.first || create_test_category
      forum = Forum.first || create_test_forum(fc)
      customer = Company.first || create_company
      put :update, :version => "v2", :format => :json, :id => forum.id, :forum => {:forum_visibility => 4, :customers => "#{customer.id}" }
      assert_response :success
      response.body.must_match_json_expression(forum_pattern(forum.reload))
    end

  end
end