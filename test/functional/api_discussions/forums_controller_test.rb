require_relative '../../test_helper'

module ApiDiscussions
  class ForumsControllerTest < ActionController::TestCase

    def test_destroy
      fc = ForumCategory.first || create_test_category
      forum = create_test_forum(fc)
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
      response.body.must_match_json_expression(forum_response_pattern(forum, {:forum_type => 2}))
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
      response.body.must_match_json_expression(forum_response_pattern(forum, {:forum_visibility => 4, :customers => "#{customer.id}"}))
    end

    def test_create_validate_presence
      post :create, :version => "v2", :format => :json, :forum => {:forum_visibility=> "1", :forum_type => 1}
      response.body.must_match_json_expression([bad_request_error_pattern("name", "can't be blank"),
      bad_request_error_pattern("forum_category_id", "can't be blank")])
      assert_response :bad_request
    end

    def test_create_validate_inclusion
      post :create, :version => "v2", :format => :json, :forum => {:name => "test", :forum_category_id => 1} 
      response.body.must_match_json_expression([bad_request_error_pattern("forum_visibility", "is not included in the list", :list => "1,2,3,4"),
      bad_request_error_pattern("forum_type", "is not included in the list", :list => "1,2,3,4")])
      assert_response :bad_request
    end

    def test_create
      post :create, :version => "v2", :format => :json, :forum => {:forum_visibility=> "1", :forum_type => 1, :name => "test", :forum_category_id => ForumCategory.first.id} 
      response.body.must_match_json_expression(forum_pattern Forum.last)
      response.body.must_match_json_expression(forum_response_pattern Forum.last, {:forum_visibility=> 1, :forum_type => 1, :name => "test", :forum_category_id => ForumCategory.first.id})
      assert_response :created
    end

    def test_create_no_params
      post :create, :version => "v2", :format => :json, :forum => {} 
      response.body.must_match_json_expression([bad_request_error_pattern("forum", "missing_field")])
      assert_response :bad_request
    end

    # def test_create_with_customers
    # end

    # def test_create_with_invalid_customers
    # end

    def test_before_filters_show
      controller.class.any_instance.expects(:verify_authenticity_token).never
      controller.class.any_instance.expects(:check_privilege).never
      controller.class.any_instance.expects(:portal_check).once
      get :show, :id => 1, :version => "v2", :format => :json      
    end

    def test_create_extra_params
      post :create, :version => "v2", :format => :json, :forum => {:account_id => 1, :test => 2} 
      response.body.must_match_json_expression([bad_request_error_pattern("account_id", "invalid_field"), bad_request_error_pattern("test", "invalid_field")])
      assert_response :bad_request
    end

    def test_create_invalid_model
      post :create, :version => "v2", :format => :json, :forum => {:forum_visibility=> "1", :forum_type => 1, :name => Forum.first.name, :forum_category_id => ForumCategory.first.id} 
      response.body.must_match_json_expression([bad_request_error_pattern("name", "already exists in the selected category")])
      assert_response :conflict
    end

    def test_show_invalid_id
      get :show, :id => "x", :version => "v2", :format => :json
      assert_response :not_found
      assert_equal " ", @response.body   
    end

    def test_show
      f = Forum.first
      get :show, :id => f.id, :version => "v2", :format => :json
      assert_response :success
      response.body.must_match_json_expression(forum_pattern(f))
    end

  end
end