require_relative '../../test_helper'

module ApiDiscussions
  class ForumsControllerTest < ActionController::TestCase

    def f_obj
      Forum.first || create_test_forum(fc)
    end

    def fc_obj
      ForumCategory.first || create_test_category
    end

    def company
      Company.first || create_company
    end

    def wrap_cname params
      {:forum => params}
    end

    def test_destroy
      fc = fc_obj
      forum = create_test_forum(fc)
      delete :destroy, construct_params(:id => forum.id)
      assert_equal " ", @response.body
      assert_response :no_content
      assert_nil Forum.find_by_id(forum.id)
    end

     def test_destroy_invalid_id
      delete :destroy, construct_params(:id => (1000 + Random.rand(11)))
      assert_equal " ", @response.body
      assert_response :not_found
    end

    def test_update
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({:id => forum.id}, {:forum_type => 2})
      assert_response :success
      match_json(forum_pattern(forum.reload))
      match_json(forum_response_pattern(forum, {:forum_type => 2}))
    end

    def test_update_blank_name
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({:id => forum.id}, {:name => " "})
      assert_response :bad_request
      match_json([bad_request_error_pattern("name", "can't be blank")])
    end


    def test_update_invalid_forum_type
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({:id => forum.id}, {:forum_type => 7897})
      assert_response :bad_request
      match_json([bad_request_error_pattern("forum_type", "is not included in the list", {:list => ApiConstants::LIST_FIELDS[:forum_type]})])
    end

    def test_update_invalid_forum_visibility
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({:id => forum.id}, {:forum_visibility => 7897})
      assert_response :bad_request
      match_json([bad_request_error_pattern("forum_visibility", "is not included in the list", {:list => ApiConstants::LIST_FIELDS[:forum_visibility]})])
    end

     def test_update_duplicate_name
      fc = fc_obj
      forum = f_obj
      another_forum = create_test_forum(fc)
      put :update, construct_params({:id => forum.id}, {:name => another_forum.name})
      assert_response :conflict
      match_json([bad_request_error_pattern("name", "already exists in the selected category")])
    end

    def test_update_unexpected_fields
      fc = fc_obj
      forum = f_obj
      another_forum = create_test_forum(fc)
      put :update, construct_params({:id => forum.id}, {:junk => another_forum.name})
      assert_response :bad_request
      match_json([bad_request_error_pattern("junk", "invalid_field")])
    end

    def test_update_missing_fields
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({:id => forum.id}, {})
      assert_response :bad_request
      match_json(request_error_pattern("missing_params"))
    end

    def test_update_invalid_forum_category_id
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({:id => forum.id}, {:forum_category_id => 89})
      assert_response :bad_request
      match_json([bad_request_error_pattern("forum_category", "can't be blank")])
    end

    def test_update_invalid_customer_id
      fc = fc_obj
      forum = f_obj
      customer = company
      put :update, construct_params({:id => forum.id}, {:forum_visibility => 4, :customers => "#{customer.id},67,78"})
      assert_response :bad_request
      match_json([bad_request_error_pattern("customers", "list is invalid", {:meta => "67, 78"})])
    end

    def test_update_with_customer_id
      fc = fc_obj
      forum = f_obj
      customer = company
      put :update, construct_params({:id => forum.id}, {:forum_visibility => 4, :customers => "#{customer.id}"})
      assert_response :success
      match_json(forum_pattern(forum.reload))
      match_json(forum_response_pattern(forum, {:forum_visibility => 4, :customers => "#{customer.id}"}))
    end

    def test_create_validate_presence
      post :create, construct_params({}, {:forum_visibility=> "1", :forum_type => 1})
      match_json([bad_request_error_pattern("name", "can't be blank"),
      bad_request_error_pattern("forum_category_id", "is not a number")])
      assert_response :bad_request
    end

    def test_create_validate_inclusion
      post :create, construct_params({}, {:name => "test", :forum_category_id => 1})
      match_json([bad_request_error_pattern("forum_visibility", "is not included in the list", :list => "1,2,3,4"),
      bad_request_error_pattern("forum_type", "is not included in the list", :list => "1,2,3,4")])
      assert_response :bad_request
    end

    def test_create
      post :create, construct_params({}, {:description => "desc", :forum_visibility=> "1",
       :forum_type => 1, :name => "test", :forum_category_id => ForumCategory.first.id})
      match_json(forum_pattern Forum.last)
      match_json(forum_response_pattern Forum.last, {:description => "desc", :forum_visibility=> 1, :forum_type => 1, :name => "test", :forum_category_id => ForumCategory.first.id})
      assert_response :created
    end

    def test_create_no_params
      post :create, construct_params({}, {})
      pattern = [bad_request_error_pattern("name", "can't be blank"), 
      bad_request_error_pattern("forum_category_id", "is not a number"),
      bad_request_error_pattern("forum_visibility", "is not included in the list", :list => "1,2,3,4"),
      bad_request_error_pattern("forum_type", "is not included in the list", :list => "1,2,3,4")]
      match_json(pattern)
      assert_response :bad_request
    end

    def test_create_invalid_customer_id
      fc = fc_obj
      customer = company
      post :create, construct_params({}, {:description => "desc", :forum_visibility=> "1", :forum_type => 1,
       :name => "customer test", :forum_category_id => fc.id, :customers => "#{customer.id},67,78"})
      assert_response :bad_request
      match_json([bad_request_error_pattern("customers", "list is invalid", {:meta => "67, 78"})])
    end

    def test_create_with_customer_id
      fc = fc_obj
      customer = company
      params = {:description => "desc", :forum_visibility=> 1, :forum_type => 1, :name => "customer test 2", :forum_category_id => ForumCategory.first.id, :customers => "#{customer.id}" }
      post :create, construct_params({}, params)
      assert_response :success
      match_json(forum_pattern(Forum.last.reload))
      match_json(forum_response_pattern(Forum.last, params))
      assert_equal Forum.last.customer_forums.collect(&:customer_id), [customer.id]
    end

    def test_before_filters_show
      controller.class.any_instance.expects(:verify_authenticity_token).never
      controller.class.any_instance.expects(:check_privilege).never
      controller.class.any_instance.expects(:portal_check).once
      get :show, construct_params(:id => 1)      
    end

    def test_create_extra_params
      post :create, construct_params({}, {:account_id => 1, :test => 2})
      match_json([bad_request_error_pattern("account_id", "invalid_field"), bad_request_error_pattern("test", "invalid_field")])
      assert_response :bad_request
    end

    def test_create_invalid_model
      post :create, construct_params({}, {:forum_visibility=> "1", :forum_type => 1, :name => Forum.first.name, :forum_category_id => ForumCategory.first.id})
      match_json([bad_request_error_pattern("name", "already exists in the selected category")])
      assert_response :conflict
    end

    def test_show_invalid_id
      get :show, construct_params(:id => "x")
      assert_response :not_found
      assert_equal " ", @response.body   
    end

    def test_show
      f = Forum.first
      get :show, construct_params(:id => f.id)
      pattern = forum_pattern(f)
      pattern[:topics] = Array
      assert_response :success
      match_json(pattern)
    end

    def test_show_with_topics
      f = Forum.where("topics_count >= ?", 1).first || create_test_topic(Forum.first, User.first).forum
      get :show, construct_params(:id => f.id)
      result_pattern = forum_pattern(f)
      result_pattern[:topics] = []
      f.topics.each do |t|
        result_pattern[:topics] << topic_pattern(t)
      end
      match_json(result_pattern)
    end

  end
end