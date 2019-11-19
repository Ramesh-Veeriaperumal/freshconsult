require_relative '../../test_helper'

module ApiDiscussions
  class CategoriesControllerTest < ActionController::TestCase
    include DiscussionsTestHelper
    actions = Rails.application.routes.routes.select { |x| x.defaults[:controller] == 'api_discussions/categories' }.map { |x| x.defaults[:action] }.uniq
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
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      end

      define_method("test_#{action}_without_login") do
        controller.class.any_instance.stubs(:api_current_user).returns(nil)
        send(methods[action], action, construct_params(id: fc.id))
        assert_response 401
        match_json(request_error_pattern(:invalid_credentials))
        controller.class.any_instance.unstub(:api_current_user)
      end

      define_method("test_#{action}_check_day_pass_usage") do
        Agent.any_instance.stubs(:occasional).returns(true).once
        subscription = @account.subscription
        subscription.update_column(:state, 'active')
        send(methods[action], action, construct_params(id: fc.id))
        match_json(request_error_pattern(:access_denied))
        assert_response 403
      end

      define_method("test_#{action}_requires_feature_disabled") do
        Account.any_instance.stubs(:enabled_features_list).returns([])
        send(methods[action], action, construct_params(id: fc.id))
        match_json(request_error_pattern(:require_feature, feature: 'Forums'))
        assert_response 403
        Account.any_instance.unstub(:enabled_features_list)
      end
    end

    # verify_authenticity_token will not get called for get requests. So All GET actions here in exclude array.
    actions.select { |a| %w(index show forums).exclude?(a) }.each do |action|
      define_method("test_#{action}_check_account_state") do
        subscription = @account.subscription
        subscription.update_column(:state, 'suspended')
        send(methods[action], action, construct_params(id: fc.id))
        match_json(request_error_pattern(:account_suspended))
        assert_response 403
        subscription.update_column(:state, 'trial')
      end
    end

    actions.select { |a| ['index', 'create'].exclude?(a) }.each do |action|
      define_method("test_#{action}_load_object_present") do
        category = fc
        ForumCategory.any_instance.stubs(:destroy).returns(true)
        send(methods[action], action, construct_params({ id: category.id }, name: 'new'))
        assert_equal category.reload, assigns(:item)
      end

      define_method("test_#{action}_load_object_not_present") do
        send(methods[action], action, construct_params(id: 'x'))
        assert_response :missing
        assert_equal ' ', @response.body
      end
    end

    def setup
      super
      @account.add_feature(:forums)
    end

    def test_create_length_invalid
      params_hash = { name: Faker::Lorem.characters(300) }
      post :create, construct_params({}, params_hash)
      match_json([bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters')])
      assert_response 400
    end

    def test_create_length_valid_with_trailing_spaces
      params_hash = { name: Faker::Lorem.characters(20) + white_space }
      post :create, construct_params({}, params_hash)
      assert_response 201
      match_json(forum_category_response_pattern(params_hash[:name].strip, nil))
      match_json(forum_category_pattern(ForumCategory.last))
    end

    def test_update_with_extra_params
      put :update, construct_params({ id: fc.id }, test: 'new')
      match_json([bad_request_error_pattern('test', :invalid_field)])
      assert_response 400
    end

    def test_update_with_missing_params
      put :update, construct_params({ id: fc.id }, {})
      assert_response 400
      match_json(request_error_pattern(:missing_params))
    end

    def test_update_with_blank_name
      put :update, construct_params({ id: fc.id }, name: '')
      match_json([bad_request_error_pattern('name', :blank)])
      assert_response 400
    end

    def test_update_with_invalid_model
      fc_1 = create_test_category
      fc_2 = create_test_category
      put :update, construct_params({ id: fc_1.id }, name: fc_2.name)
      match_json([bad_request_error_pattern('name', :'has already been taken')])
      assert_response 409
    ensure
      fc_1.destroy
      fc_2.destroy
    end

    def test_update_length_invalid
      new_fc = create_test_category
      put :update, construct_params({ id: fc.id }, name: Faker::Lorem.characters(300))
      match_json([bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters')])
      assert_response 400
    end

    def test_update_length_valid_with_trailing_space
      new_fc = create_test_category
      name =  Faker::Lorem.characters(20) + white_space
      put :update, construct_params({ id: new_fc.id }, name: name)
      match_json(forum_category_response_pattern(name.strip, new_fc.reload.description))
      match_json(forum_category_pattern(new_fc.reload))
      assert_response 200
    end

    def test_update
      forum_category = fc
      put :update, construct_params({ id: forum_category.id }, description: 'foo')
      match_json(forum_category_response_pattern(forum_category.name, 'foo'))
      match_json(forum_category_pattern(forum_category.reload))
      assert_response 200
      assert_equal 'foo', ForumCategory.find_by_id(forum_category.id).description
    end

    def test_destroy
      ForumCategory.any_instance.unstub(:destroy)
      fc = @account.forum_categories.create!(name: 'temp')
      delete :destroy, construct_params(id: fc.id)
      assert_equal ' ', @response.body
      assert_response 204
      assert_nil ForumCategory.find_by_id(fc.id)
    end

    def test_show
      get :show, construct_params(id: fc.id)
      result_pattern = forum_category_response_pattern(fc.name, fc.description)
      assert_response 200
      match_json(result_pattern)
    end

    def test_show_invalid_id
      get :show, construct_params(id: 'x')
      assert_response :missing
      assert_equal ' ', @response.body
    end

    def test_show_portal_check
      User.any_instance.stubs(:privilege?).returns(false).once
      get :show, construct_params(id: fc.id)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_create
      post :create, construct_params({}, name: 'test', description: 'test desc')
      assert_response 201
      match_json(forum_category_response_pattern('test', 'test desc'))
      match_json(forum_category_pattern(ForumCategory.last))
    end

    def test_create_missing_params
      post :create, construct_params({}, {})
      pattern = [
        bad_request_error_pattern('name', :datatype_mismatch, code: :missing_field, expected_data_type: String)
      ]
      assert_response 400
      match_json(pattern)
    end

    def test_create_unexpected_params
      post :create, construct_params({}, 'junk' => 'new')
      pattern = [
        bad_request_error_pattern('junk', :invalid_field)
      ]
      assert_response 400
      match_json(pattern)
    end

    def test_create_blank_name
      post :create, construct_params({}, 'name' => '')
      pattern = [
        bad_request_error_pattern('name', :blank)
      ]
      assert_response 400
      match_json(pattern)
    end

    def test_create_with_duplicate_name
      fc = create_test_category
      post :create, construct_params({}, 'name' => fc.name)
      pattern = [
        bad_request_error_pattern('name', :'has already been taken')
      ]
      assert_response 409
      match_json(pattern)
    end

    def test_update_with_nil_name
      put :update, construct_params({ id: fc.id }, name: nil)
      match_json([bad_request_error_pattern('name', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null')])
      assert_response 400
    end

    def test_index
      get :index, controller_params
      pattern = []
      Account.current.forum_categories.all.each do |fc|
        pattern << forum_category_response_pattern(fc.name, fc.description)
      end
      assert_response 200
      match_json(pattern)
    end

    def test_render_500
      controller.class.any_instance.stubs(:index).raises(StandardError)
      Rails.env.stubs(:test?).returns(false)
      @request.stubs(:ssl?).returns(true)
      get :index, controller_params
      Rails.env.unstub(:test?)
      @request.unstub(:ssl?)
      assert_response 500
      match_json(base_error_pattern(:internal_error))
    end

    def test_ensure_proper_protocol
      Rails.env.stubs(:test?).returns(false).once
      get :index, controller_params
      Rails.env.unstub(:test?)
      assert_response 403
      match_json(request_error_pattern(:ssl_required))
    end

    def test_create_returns_location_header
      name = Faker::Name.name
      post :create, construct_params({}, 'name' => name, 'description' => 'test desc')
      result = parse_response(@response.body)
      assert_response 201
      match_json(forum_category_response_pattern(name))
      match_json(forum_category_pattern(ForumCategory.last))
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/discussions/categories/#{result['id']}", response.headers['Location']
    end

    def test_index_with_pagination
      3.times do
        create_test_category
      end
      get :index, controller_params(per_page: 1)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      get :index, controller_params(per_page: 1, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      get :index, controller_params(per_page: 1, page: 3)
      assert_response 200
      assert JSON.parse(response.body).count == 1
    end

    def test_index_with_pagination_exceeds_limit
      get :index, controller_params(per_page: 101)
      assert_response 400
      match_json([bad_request_error_pattern('per_page', :per_page_invalid, max_value: 100)])
    end

    def test_index_with_link_header
      3.times do
        create_test_category
      end
      per_page = ForumCategory.count - 1
      get :index, controller_params(per_page: per_page)
      assert_response 200
      pattern = []
      Account.current.forum_categories.limit(per_page).reorder(:name).each do |fc|
        pattern << forum_category_response_pattern(fc.name, fc.description)
      end
      match_json(pattern.ordered!)
      assert JSON.parse(response.body).count == per_page
      assert_equal "<http://#{@request.host}/api/v2/discussions/categories?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

      get :index, controller_params(per_page: per_page, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      assert_nil response.headers['Link']
    end
  end
end
