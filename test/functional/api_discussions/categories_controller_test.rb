require_relative '../../test_helper'

module ApiDiscussions
  class CategoriesControllerTest < ActionController::TestCase
    include ForumHelper
    
    actions = Rails.application.routes.routes.select{|x| x.defaults[:controller] == "api_discussions/categories"}.collect{|x| x.defaults[:action]}.uniq
    methods = {"index" => :get, "create" => :post, "update" => :put, "destroy" => :delete, "show" => :get}
    
    def fc
      ForumCategory.first
    end

    actions.select{|x| x != "show"}.each do |action|
      define_method("test_#{action}_without_privilege") do 
        controller.class.any_instance.stubs(:allowed_to_access?).returns(false).once
        send(methods[action], action, :version => "v2", :format => :json, :id => fc.id)
        assert_response :forbidden
        response.body.must_match_json_expression(request_error_pattern("access_denied"))
      end

      define_method("test_#{action}_without_login") do 
        controller.class.any_instance.stubs(:current_user).returns(nil)
        send(methods[action], action, :version => "v2", :format => :json, :id => fc.id)
        assert_response :unauthorized
        response.body.must_match_json_expression(request_error_pattern("invalid_credentials"))
        controller.class.any_instance.unstub(:current_user)
      end

      define_method("test_#{action}_check_day_pass_usage") do
        Agent.any_instance.stubs(:occasional).returns(true).once
        subscription = @account.subscription
        subscription.update_column(:state, "active")
        send(methods[action], action, :version => "v2", :format => :json, :id => fc.id)
        response.body.must_match_json_expression(request_error_pattern("access_denied"))
        assert_response :forbidden
      end

      define_method("test_#{action}_requires_feature_disabled") do
        controller.class.any_instance.stubs(:feature?).returns(false).once
        send(methods[action], action, :version => "v2", :format => :json, :id => fc.id)
        response.body.must_match_json_expression(request_error_pattern("require_feature", {:feature => "Forums"}))
        assert_response :forbidden
      end
    end

    actions.select{|a| ["index", "show"].exclude?(a)}.each do |action|
      define_method("test_#{action}_without_token") do 
        with_forgery_protection do
          @request.cookies["_helpkit_session"] = true
          send(methods[action], action, :version => "v2", :format => :json, :id => fc.id, :authenticity_token => 'foo')
        end
        assert_response :unauthorized
        response.body.must_match_json_expression(request_error_pattern("unverified_request"))
      end

      define_method("test_#{action}_check_account_state_and_response_headers") do 
        subscription = @account.subscription
        subscription.update_column(:state, "suspended")
        send(methods[action], action, :version => "v2", :format => :json, :id => fc.id)
        response.body.must_match_json_expression(request_error_pattern("account_suspended"))
        assert_response :forbidden
        assert_equal "current=v2; requested=v2", @response.headers["X-Freshdesk-API-Version"] 
        assert_not_nil @response.headers["X-RateLimit-Limit"] 
        assert_not_nil @response.headers["X-RateLimit-Remaining"] 
        subscription.update_column(:state, "trial")
      end
    end

    actions.select{|a| ["index", "create"].exclude?(a)}.each do |action|
      define_method("test_#{action}_load_object_present") do
        ForumCategory.any_instance.stubs(:destroy).returns(true)
        send(methods[action], action, :version => "v2", :format => :json, :id => fc.id, :category => {:name => "new"})
        assert_equal fc, assigns(:category)
        assert_equal fc, assigns(:item)
      end

      define_method("test_#{action}_load_object_not_present") do
        send(methods[action], action, :version => "v2", :format => :json, :id => 'x')
        assert_response :not_found
        assert_equal " ", @response.body
      end
    end
    
    def test_index_load_objects
      get :index, :version => "v2", :format => :json
      assert_equal ForumCategory.all, assigns(:items)
      assert_equal ForumCategory.all, assigns(:categories)
    end

    def test_update_with_extra_params
      put :update, :version => "v2", :format => :json, :id => fc.id, :category => {:test => "new"}
      response.body.must_match_json_expression([bad_request_error_pattern("test", "invalid_field")])
      assert_response :bad_request
    end

    def test_update_with_missing_params
      put :update, :version => "v2", :format => :json, :id => fc.id, :category => {}
      response.body.must_match_json_expression([bad_request_error_pattern("category", "missing_field")])
      assert_response :bad_request
    end

    def test_update_with_blank_name
      put :update, :version => "v2", :format => :json, :id => fc.id, :category => {:name => ""}
      response.body.must_match_json_expression([bad_request_error_pattern("name", "can't be blank")])
      assert_response :bad_request
    end

    def test_update_with_invalid_model
      new_fc = create_test_category
      put :update, :version => "v2", :format => :json, :id => fc.id, :category => {:name => new_fc.name}
      response.body.must_match_json_expression([bad_request_error_pattern("name", "has already been taken")])
      assert_response :conflict
    end

    def test_update
      put :update, :version => "v2", :format => :json, :id => fc.id, :category => {:description => "foo"}
      response.body.must_match_json_expression(forum_category_pattern(fc.name, "foo"))
      assert_response :success
      assert_equal "foo", ForumCategory.find_by_id(fc.id).description
    end

    def test_destroy
      ForumCategory.any_instance.unstub(:destroy)
      fc = @account.forum_categories.create!(:name => "temp")
      delete :destroy, :version => "v2", :format => :json, :id => fc.id
      assert_equal " ", @response.body
      assert_response :no_content
      assert_nil ForumCategory.find_by_id(fc.id)
    end

    def test_show
      get :show, :version => "v2", :format => :json, :id => fc.id
      assert_response :success
      response.body.must_match_json_expression(forum_category_pattern(fc.name, fc.description))
    end

    def test_show_portal_check
      controller.class.any_instance.stubs(:privilege?).with(:view_forums).returns(false).once
      get :show, :version => "v2", :format => :json, :id => fc.id
      assert_response :forbidden
      response.body.must_match_json_expression(request_error_pattern("access_denied"))
    end

    def test_create
      post :create, :version => "v2", :format => :json, :category => {:name => "test", :description => "test desc"}
      assert_response :success
      response.body.must_match_json_expression(forum_category_pattern("test", "test desc"))
    end

    def test_create_missing_params
      post :create, :version => "v2", :format => :json, :category => {}
      pattern = [
        bad_request_error_pattern("category", "missing_field")
      ]
      assert_response :bad_request
      response.body.must_match_json_expression(pattern)
    end

    def test_create_unexpected_params
      post :create, :version => "v2", :format => :json, :category => {"junk" => "new"}
      pattern = [
        bad_request_error_pattern("junk", "invalid_field")
      ]
      assert_response :bad_request
      response.body.must_match_json_expression(pattern)
    end

    def test_create_blank_name
      post :create, :version => "v2", :format => :json, :category => {"name" => ""}
      pattern = [
        bad_request_error_pattern("name", "can't be blank")
      ]
      assert_response :bad_request
      response.body.must_match_json_expression(pattern)
    end

    def test_create_with_duplicate_name
      fc = create_test_category
      post :create, :version => "v2", :format => :json, :category => {"name" => fc.name}
      pattern = [
        bad_request_error_pattern("name", "has already been taken")
      ]
      assert_response :conflict
      response.body.must_match_json_expression(pattern)
    end

    def test_index
      get :index, :version => "v2", :format => :json
      pattern = []
      Account.current.forum_categories.all.each do |fc|
        pattern << forum_category_pattern(fc.name, fc.description)
      end
      assert_response :success
      response.body.must_match_json_expression(pattern)
    end

    def test_render_500
      controller.class.any_instance.stubs(:index).raises(StandardError)
      get :index, :version => "v2", :format => :json
      assert_response :internal_server_error
      response.body.must_match_json_expression(base_error_pattern("internal_error"))
    end

    def test_ensure_proper_protocol
      Rails.env.stubs(:test?).returns(false).once
      get :index, :version => "v2", :format => :json
      Rails.env.unstub(:test?)
      assert_response :forbidden
      response.body.must_match_json_expression(request_error_pattern("ssl_required"))
    end

    def test_create_returns_location_header
      name = Faker::Name.name
      post :create, :version => "v2", :format => :json, :category => {"name" => name, "description" => "test desc"}
      result = parse_response(@response.body)
      assert_response :success
      @response.body.must_match_json_expression(forum_category_pattern(name))
      assert_equal true, response.headers.include?("Location")
      assert_equal "http://#{@request.host}/api/v2/discussions/categories/#{result["id"]}", response.headers["Location"]
    end
  end
end