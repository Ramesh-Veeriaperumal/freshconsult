require_relative '../../test_helper'

module ApiDiscussions
  class CategoriesControllerTest < ActionController::TestCase
    actions = Rails.application.routes.routes.select { |x| x.defaults[:controller] == 'api_discussions/categories' }.collect { |x| x.defaults[:action] }.uniq
    methods = { 'index' => :get, 'create' => :post, 'update' => :put, 'destroy' => :delete, 'show' => :get, 'forums' => :get }

    def fc
      ForumCategory.first
    end

    def wrap_cname(params)
      { category: params }
    end

    actions.select { |x| x != 'show' }.each do |action|
      define_method("test_#{action}_without_privilege") do
        controller.class.any_instance.stubs(:allowed_to_access?).returns(false).once
        send(methods[action], action, construct_params(id: fc.id))
        assert_response :forbidden
        match_json(request_error_pattern('access_denied'))
      end

      define_method("test_#{action}_without_login") do
        controller.class.any_instance.stubs(:current_user).returns(nil)
        send(methods[action], action, construct_params(id: fc.id))
        assert_response :unauthorized
        match_json(request_error_pattern('invalid_credentials'))
        controller.class.any_instance.unstub(:current_user)
      end

      define_method("test_#{action}_check_day_pass_usage") do
        Agent.any_instance.stubs(:occasional).returns(true).once
        subscription = @account.subscription
        subscription.update_column(:state, 'active')
        send(methods[action], action, construct_params(id: fc.id))
        match_json(request_error_pattern('access_denied'))
        assert_response :forbidden
      end

      define_method("test_#{action}_requires_feature_disabled") do
        @account.class.any_instance.stubs(:features_included?).returns(false).once
        send(methods[action], action, construct_params(id: fc.id))
        match_json(request_error_pattern('require_feature', feature: 'Forums'))
        assert_response :forbidden
      end
    end

    # verify_authenticity_token will not get called for get requests. So All GET actions here in exclude array.
    actions.select { |a| %w(index show forums).exclude?(a) }.each do |action|
      define_method("test_#{action}_check_account_state_and_response_headers") do
        subscription = @account.subscription
        subscription.update_column(:state, 'suspended')
        send(methods[action], action, construct_params(id: fc.id))
        match_json(request_error_pattern('account_suspended'))
        assert_response :forbidden
        assert_equal 'current=v2; requested=v2', @response.headers['X-Freshdesk-API-Version']
        subscription.update_column(:state, 'trial')
      end
    end

    actions.select { |a| ['index', 'create'].exclude?(a) }.each do |action|
      define_method("test_#{action}_load_object_present") do
        ForumCategory.any_instance.stubs(:destroy).returns(true)
        send(methods[action], action, construct_params({ id: fc.id }, name: 'new'))
        assert_equal fc, assigns(:item)
      end

      define_method("test_#{action}_load_object_not_present") do
        send(methods[action], action, construct_params(id: 'x'))
        assert_response :not_found
        assert_equal ' ', @response.body
      end
    end

    def test_index_load_objects
      get :index, request_params
      assert_equal ForumCategory.all, assigns(:items)
    end

    def test_update_with_extra_params
      put :update, construct_params({ id: fc.id }, test: 'new')
      match_json([bad_request_error_pattern('test', 'invalid_field')])
      assert_response :bad_request
    end

    def test_update_with_missing_params
      put :update, construct_params({ id: fc.id }, {})
      assert_response :bad_request
      match_json(request_error_pattern('missing_params'))
    end

    def test_update_with_blank_name
      put :update, construct_params({ id: fc.id }, name: '')
      match_json([bad_request_error_pattern('name', "can't be blank")])
      assert_response :bad_request
    end

    def test_update_with_invalid_model
      new_fc = create_test_category
      put :update, construct_params({ id: fc.id }, name: new_fc.name)
      match_json([bad_request_error_pattern('name', 'has already been taken')])
      assert_response :conflict
    end

    def test_update
      put :update, construct_params({ id: fc.id }, description: 'foo')
      match_json(forum_category_response_pattern(fc.name, 'foo'))
      match_json(forum_category_pattern(fc))
      assert_response :success
      assert_equal 'foo', ForumCategory.find_by_id(fc.id).description
    end

    def test_destroy
      ForumCategory.any_instance.unstub(:destroy)
      fc = @account.forum_categories.create!(name: 'temp')
      delete :destroy, construct_params(id: fc.id)
      assert_equal ' ', @response.body
      assert_response :no_content
      assert_nil ForumCategory.find_by_id(fc.id)
    end

    def test_show
      get :show, construct_params(id: fc.id)
      assert_response :success
      result_pattern = forum_category_response_pattern(fc.name, fc.description)
      result_pattern[:forums] = Array
      assert_response :success
      match_json(result_pattern)
    end

    def test_show_with_forums
      fc = Forum.first.forum_category
      get :show, construct_params(id: fc.id)
      assert_response :success
      result_pattern = forum_category_response_pattern(fc.name, fc.description)
      result_pattern[:forums] = []
      fc.forums.each do |f|
        result_pattern[:forums] << forum_pattern(f)
      end
      assert_response :success
      match_json(result_pattern)
    end

    def test_show_invalid_id
      get :show, construct_params(id: 'x')
      assert_response :not_found
      assert_equal ' ', @response.body
    end

    def test_show_portal_check
      User.any_instance.stubs(:privilege?).returns(false).once
      get :show, construct_params(id: fc.id)
      assert_response :forbidden
      match_json(request_error_pattern('access_denied'))
    end

    def test_create
      post :create, construct_params({}, name: 'test', description: 'test desc')
      assert_response :success
      match_json(forum_category_response_pattern('test', 'test desc'))
      match_json(forum_category_pattern(ForumCategory.last))
    end

    def test_create_missing_params
      post :create, construct_params({}, {})
      pattern = [
        bad_request_error_pattern('name', 'missing_field')
      ]
      assert_response :bad_request
      match_json(pattern)
    end

    def test_create_unexpected_params
      post :create, construct_params({}, 'junk' => 'new')
      pattern = [
        bad_request_error_pattern('junk', 'invalid_field')
      ]
      assert_response :bad_request
      match_json(pattern)
    end

    def test_create_blank_name
      post :create, construct_params({}, 'name' => '')
      pattern = [
        bad_request_error_pattern('name', "can't be blank")
      ]
      assert_response :bad_request
      match_json(pattern)
    end

    def test_create_with_duplicate_name
      fc = create_test_category
      post :create, construct_params({}, 'name' => fc.name)
      pattern = [
        bad_request_error_pattern('name', 'has already been taken')
      ]
      assert_response :conflict
      match_json(pattern)
    end

    def test_update_with_nil_name
      put :update, construct_params({ id: fc.id }, name: nil)
      match_json([bad_request_error_pattern('name', "can't be blank")])
      assert_response :bad_request
    end

    def test_index
      get :index, request_params
      pattern = []
      Account.current.forum_categories.all.each do |fc|
        pattern << forum_category_response_pattern(fc.name, fc.description)
      end
      assert_response :success
      match_json(pattern)
    end

    def test_render_500
      controller.class.any_instance.stubs(:index).raises(StandardError)
      Rails.env.stubs(:test?).returns(false)
      @request.stubs(:ssl?).returns(true)
      get :index, request_params
      Rails.env.unstub(:test?)
      @request.unstub(:ssl?)
      assert_response :internal_server_error
      match_json(base_error_pattern('internal_error'))
    end

    def test_ensure_proper_protocol
      Rails.env.stubs(:test?).returns(false).once
      get :index, request_params
      Rails.env.unstub(:test?)
      assert_response :forbidden
      match_json(request_error_pattern('ssl_required'))
    end

    def test_create_returns_location_header
      name = Faker::Name.name
      post :create, construct_params({}, 'name' => name, 'description' => 'test desc')
      result = parse_response(@response.body)
      assert_response :success
      match_json(forum_category_response_pattern(name))
      match_json(forum_category_pattern(ForumCategory.last))
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/discussions/categories/#{result['id']}", response.headers['Location']
    end

    def test_forums
      get :forums, construct_params(id: fc.id)
      assert_response :success
      result_pattern = []
      fc.forums.each do |f|
        result_pattern << forum_pattern(f)
      end
      match_json(result_pattern)
    end

    def test_forums_invalid_id
      get :forums, construct_params(id: 'x')
      assert_response :not_found
      assert_equal ' ', @response.body
    end

    def test_forums_with_pagination
      3.times do
        create_test_forum(fc)
      end
      get :forums, construct_params(id: fc.id, per_page: 1)
      assert_response :success
      assert JSON.parse(response.body).count == 1
      get :forums, construct_params(id: fc.id, per_page: 1, page: 2)
      assert_response :success
      assert JSON.parse(response.body).count == 1
      get :forums, construct_params(id: fc.id, per_page: 1, page: 3)
      assert_response :success
      assert JSON.parse(response.body).count == 1
    end

    def test_forums_with_pagination_exceeds_limit
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:per_page).returns(2)
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:max_per_page).returns(3)
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:page).returns(1)
      get :forums, construct_params(id: fc.id, per_page: 4)
      assert_response :success
      assert JSON.parse(response.body).count == 3
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.unstub(:[])
    end
  end
end
