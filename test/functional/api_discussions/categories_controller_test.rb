require_relative '../../test_helper'

module ApiDiscussions
  class CategoriesControllerTest < ActionController::TestCase
    include ForumHelper
    
    actions = Rails.application.routes.routes.select{|x| x.defaults[:controller] == "api_discussions/categories"}.collect{|x| x.defaults[:action]}.uniq
    methods = {"index" => :get, "create" => :post, "update" => :put, "destroy" => :delete}
    
    def fc_id
      ForumCategory.first.id
    end

    actions.each do |action|
      define_method("test_#{action}_without_privilege") do 
        controller.class.any_instance.stubs(:allowed_to_access?).returns(false).once
        send(methods[action], action, :version => "v2", :format => :json, :id => fc_id)
        response = parse_response(@response.body)
        assert_response :forbidden
        assert_equal({"code"=>"access_denied", "message"=>"You are not authorized to perform this action."}, response)
      end

      define_method("test_#{action}_without_login") do 
        controller.class.any_instance.stubs(:current_user).returns(nil)
        send(methods[action], action, :version => "v2", :format => :json, :id => fc_id)
        response = parse_response(@response.body)
        assert_response :unauthorized
        assert_equal({"code"=>"invalid_credentials", "message"=>"You have to be logged in to perform this action."}, response)
        controller.class.any_instance.unstub(:current_user)
      end

      define_method("test_#{action}_check_day_pass_usage") do
        Agent.any_instance.stubs(:occasional).returns(true).once
        subscription = @account.subscription
        subscription.update_column(:state, "active")
        send(methods[action], action, :version => "v2", :format => :json, :id => fc_id)
        response = parse_response(@response.body)
        assert_equal({"code"=>"access_denied", "message" => "You are not authorized to perform this action."}, response)
        assert_response :forbidden
      end

      define_method("test_#{action}_requires_feature_disabled") do
        controller.class.any_instance.stubs(:feature?).returns(false).once
        send(methods[action], action, :version => "v2", :format => :json, :id => fc_id)
        response = parse_response(@response.body)
        assert_equal({"code"=>"require_feature", "message" => "The Forums feature is not supported in your plan. Please upgrade your account to use it."}, response) 
        assert_response :forbidden
      end
    end

    actions.select{|a| a != "index"}.each do |action|
      define_method("test_#{action}_without_token") do 
        with_forgery_protection do
          @request.cookies["_helpkit_session"] = true
          send(methods[action], action, :version => "v2", :format => :json, :id => fc_id, :authenticity_token => 'foo')
        end
        response = parse_response(@response.body)
        assert_response :unauthorized
        assert_equal({"code"=>"unverified_request", "message"=>"You have initiated a unverifiable request."}, response)
      end

      define_method("test_#{action}_check_account_state_and_response_headers") do 
        subscription = @account.subscription
        subscription.update_column(:state, "suspended")
        send(methods[action], action, :version => "v2", :format => :json, :id => fc_id)
        response = parse_response(@response.body)   
        assert_equal({"code"=>"account_suspended", "message" => "Your account has been suspended."}, response)
        assert_response :forbidden
        assert_equal "current=v2; requested=v2", @response.headers["X-Freshdesk-API-Version"] 
        assert_not_nil @response.headers["X-RateLimit-Limit"] 
        assert_not_nil @response.headers["X-RateLimit-Remaining"] 
        subscription.update_column(:state, "trial")
      end
    end

    actions.select{|a| ["update", "destroy"].include?(a)}.each do |action|
      define_method("test_#{action}_load_object_present") do
        fc = ForumCategory.find_by_id(fc_id)
        ForumCategory.any_instance.stubs(:destroy).returns(true)
        send(methods[action], action, :version => "v2", :format => :json, :id => fc_id, :category => {:name => "new"})
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
      put :update, :version => "v2", :format => :json, :id => fc_id, :category => {:test => "new"}
      response = parse_response(@response.body)
      assert_equal([{"field"=>"test", "message"=>"Unexpected/invalid field in request", "code"=>"invalid_field"}], response)
      assert_response :bad_request
    end

    def test_update_with_missing_params
      put :update, :version => "v2", :format => :json, :id => fc_id, :category => {}
      response = parse_response(@response.body)
      assert_equal([{"field"=>"category", "message"=>"Mandatory attribute missing", "code"=>"missing_field"}], response)
      assert_response :bad_request
    end

    def test_update_with_blank_name
      put :update, :version => "v2", :format => :json, :id => fc_id, :category => {:name => ""}
      response = parse_response(@response.body)
      assert_equal([{"field"=>"name", "message"=>"Should not be blank", "code"=>"invalid_value"}], response)
      assert_response :bad_request
    end

    def test_update_with_invalid_model
      new_fc = create_test_category
      put :update, :version => "v2", :format => :json, :id => fc_id, :category => {:name => new_fc.name}
      response = parse_response(@response.body)
      assert_equal([{"field"=>"name", "message"=>"Should be a unique value", "code"=>"already_exists"}], response)
      assert_response :conflict
    end

    def test_update
      fc = ForumCategory.find_by_id(fc_id)
      put :update, :version => "v2", :format => :json, :id => fc_id, :category => {:description => "foo"}
      response = parse_response(@response.body)
      assert_equal({"id"=>1, "name"=>"Test Account Forums", "description"=>"foo", "position"=>1, "created_at"=>fc.created_at.utc.strftime("%FT%TZ"), "updated_at"=>fc.reload.updated_at.utc.strftime("%FT%TZ")}, response)
      assert_response :success
      assert_equal "foo", ForumCategory.find_by_id(fc_id).description
    end

    def test_destroy
      ForumCategory.any_instance.unstub(:destroy)
      fc = @account.forum_categories.create!(:name => "temp")
      delete :destroy, :version => "v2", :format => :json, :id => fc.id
      assert_equal " ", @response.body
      assert_response :no_content
      assert_nil ForumCategory.find_by_id(fc.id)
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
      response = parse_response(@response.body)
      assert_equal({"message" => "We're sorry, but something went wrong."}, response)
    end

    def test_ensure_proper_protocol
      Rails.env.stubs(:test?).returns(false).once
      get :index, :version => "v2", :format => :json
      Rails.env.unstub(:test?)
      assert_response :forbidden
      response = parse_response(@response.body)
      assert_equal({"code" => "ssl_required", "message" => "SSL certificate verification failed."}, response)

    end
  end
end