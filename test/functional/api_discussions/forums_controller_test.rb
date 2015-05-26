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

    def wrap_cname(params)
      { forum: params }
    end

    def test_destroy
      fc = fc_obj
      forum = create_test_forum(fc)
      delete :destroy, construct_params(id: forum.id)
      assert_equal ' ', @response.body
      assert_response :no_content
      assert_nil Forum.find_by_id(forum.id)
    end

    def test_destroy_invalid_id
      delete :destroy, construct_params(id: (1000 + Random.rand(11)))
      assert_equal ' ', @response.body
      assert_response :not_found
    end

    def test_update
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({ id: forum.id }, forum_type: 2)
      assert_response :success
      match_json(forum_pattern(forum.reload))
      match_json(forum_response_pattern(forum, forum_type: 2))
    end

    def test_update_blank_name
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({ id: forum.id }, name: ' ')
      assert_response :bad_request
      match_json([bad_request_error_pattern('name', "can't be blank")])
    end

    def test_update_invalid_forum_type
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({ id: forum.id }, forum_type: 7897)
      assert_response :bad_request
      match_json([bad_request_error_pattern('forum_type', 'is not included in the list', list: ApiConstants::LIST_FIELDS[:forum_type])])
    end

    def test_update_invalid_forum_visibility
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({ id: forum.id }, forum_visibility: 7897)
      assert_response :bad_request
      match_json([bad_request_error_pattern('forum_visibility', 'is not included in the list', list: ApiConstants::LIST_FIELDS[:forum_visibility])])
    end

    def test_update_duplicate_name
      fc = fc_obj
      forum = f_obj
      another_forum = create_test_forum(fc)
      put :update, construct_params({ id: forum.id }, name: another_forum.name)
      assert_response :conflict
      match_json([bad_request_error_pattern('name', 'already exists in the selected category')])
    end

    def test_update_unexpected_fields
      fc = fc_obj
      forum = f_obj
      another_forum = create_test_forum(fc)
      put :update, construct_params({ id: forum.id }, junk: another_forum.name)
      assert_response :bad_request
      match_json([bad_request_error_pattern('junk', 'invalid_field')])
    end

    def test_update_missing_fields
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({ id: forum.id }, {})
      assert_response :bad_request
      match_json(request_error_pattern('missing_params'))
    end

    def test_update_invalid_forum_category_id
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({ id: forum.id }, forum_category_id: 89)
      assert_response :bad_request
      match_json([bad_request_error_pattern('forum_category', "can't be blank")])
    end

    def test_update_invalid_customer_id
      fc = fc_obj
      forum = f_obj
      customer = company
      put :update, construct_params({ id: forum.id }, forum_visibility: 4, customers: "#{customer.id},67,78")
      assert_response :bad_request
      match_json([bad_request_error_pattern('customers', 'list is invalid', meta: '67, 78')])
    end

    def test_update_with_customer_id
      fc = fc_obj
      forum = f_obj
      customer = company
      put :update, construct_params({ id: forum.id }, forum_visibility: 4, customers: "#{customer.id}")
      assert_response :success
      match_json(forum_pattern(forum.reload))
      match_json(forum_response_pattern(forum, forum_visibility: 4, customers: "#{customer.id}"))
    end

    def test_create_validate_presence
      post :create, construct_params({}, forum_visibility: '1', forum_type: 1)
      match_json([bad_request_error_pattern('name', "can't be blank"),
                  bad_request_error_pattern('forum_category_id', 'is not a number')])
      assert_response :bad_request
    end

    def test_create_validate_inclusion
      post :create, construct_params({}, name: 'test', forum_category_id: 1)
      match_json([bad_request_error_pattern('forum_visibility', 'is not included in the list', list: '1,2,3,4'),
                  bad_request_error_pattern('forum_type', 'is not included in the list', list: '1,2,3,4')])
      assert_response :bad_request
    end

    def test_create
      post :create, construct_params({}, description: 'desc', forum_visibility: '1',
                                         forum_type: 1, name: 'test', forum_category_id: ForumCategory.first.id)
      match_json(forum_pattern Forum.last)
      match_json(forum_response_pattern Forum.last, description: 'desc', forum_visibility: 1, forum_type: 1, name: 'test', forum_category_id: ForumCategory.first.id)
      assert_response :created
    end

    def test_create_returns_location_header
      name = Faker::Name.name
      post :create, construct_params({}, description: 'desc', forum_visibility: '1',
                                         forum_type: 1, name: name, forum_category_id: ForumCategory.first.id)
      match_json(forum_pattern Forum.last)
      match_json(forum_response_pattern Forum.last, description: 'desc', forum_visibility: 1, forum_type: 1, name: name, forum_category_id: ForumCategory.first.id)
      assert_response :created
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/discussions/forums/#{result['id']}", response.headers['Location']
    end


    def test_create_no_params
      post :create, construct_params({}, {})
      pattern = [bad_request_error_pattern('name', "can't be blank"),
                 bad_request_error_pattern('forum_category_id', 'is not a number'),
                 bad_request_error_pattern('forum_visibility', 'is not included in the list', list: '1,2,3,4'),
                 bad_request_error_pattern('forum_type', 'is not included in the list', list: '1,2,3,4')]
      match_json(pattern)
      assert_response :bad_request
    end

    def test_create_invalid_customer_id
      fc = fc_obj
      customer = company
      post :create, construct_params({}, description: 'desc', forum_visibility: '4', forum_type: 1,
                                         name: 'customer test', forum_category_id: fc.id, customers: "#{customer.id},67,78")
      assert_response :bad_request
      match_json([bad_request_error_pattern('customers', 'list is invalid', meta: '67, 78')])
    end

    def test_create_with_customer_id
      fc = fc_obj
      customer = company
      params = { description: 'desc', forum_visibility: 4, forum_type: 1, name: 'customer test 2', forum_category_id: ForumCategory.first.id, customers: "#{customer.id}" }
      post :create, construct_params({}, params)
      assert_response :success
      match_json(forum_pattern(Forum.last.reload))
      match_json(forum_response_pattern(Forum.last, params))
      assert_equal Forum.last.customer_forums.collect(&:customer_id), [customer.id]
    end

    def test_create_with_customer_id_and_visibility_not_company_users
      fc = fc_obj
      customer = company
      params = { description: 'desc', forum_visibility: 1, forum_type: 1, name: 'customer test 2', forum_category_id: ForumCategory.first.id, customers: "#{customer.id}" }
      post :create, construct_params({}, params)
      match_json([bad_request_error_pattern('customers', 'invalid_field')])
      assert_response :bad_request
    end

    def test_update_with_customer_id_and_visibility_not_company_users
      fc = fc_obj
      forum = f_obj
      customer = company
      put :update, construct_params({ id: forum.id }, forum_visibility: 1, customers: "#{customer.id}")
      match_json([bad_request_error_pattern('customers', 'invalid_field')])
      assert_response :bad_request
    end

    def test_before_filters_show
      controller.class.any_instance.expects(:verify_authenticity_token).never
      controller.class.any_instance.expects(:check_privilege).never
      controller.class.any_instance.expects(:portal_check).once
      get :show, construct_params(id: 1)
    end

    def test_create_extra_params
      post :create, construct_params({}, account_id: 1, test: 2)
      match_json([bad_request_error_pattern('account_id', 'invalid_field'), bad_request_error_pattern('test', 'invalid_field')])
      assert_response :bad_request
    end

    def test_create_invalid_model
      post :create, construct_params({}, forum_visibility: '1', forum_type: 1, name: Forum.first.name, forum_category_id: ForumCategory.first.id)
      match_json([bad_request_error_pattern('name', 'already exists in the selected category')])
      assert_response :conflict
    end

    def test_show_invalid_id
      get :show, construct_params(id: 'x')
      assert_response :not_found
      assert_equal ' ', @response.body
    end

    def test_show
      f = Forum.first
      get :show, construct_params(id: f.id)
      pattern = forum_pattern(f)
      pattern[:topics] = Array
      assert_response :success
      match_json(pattern)
    end

    def test_show_with_topics
      forum = Forum.first
      create_test_topic(forum, User.first)
      forum.reload
      get :show, construct_params(id: forum.id)
      result_pattern = forum_pattern(forum)
      result_pattern[:topics] = []
      forum.topics.each do |t|
        result_pattern[:topics] << topic_pattern(t)
      end
      match_json(result_pattern)
      assert_response :success
    end

    def test_topics_invalid_id
      get :topics, construct_params(id: 'x')
      assert_response :not_found
      assert_equal ' ', @response.body
    end

    def test_topics
      f = Forum.where('topics_count >= ?', 1).first || create_test_topic(Forum.first, User.first).forum
      get :topics, construct_params(id: f.id)
      result_pattern = []
      f.topics.each do |t|
        result_pattern << topic_pattern(t)
      end
      assert_response :success
      match_json(result_pattern)
    end

    def test_topics_with_pagination
      3.times do
        create_test_topic(f_obj, User.first)
      end
      get :topics, construct_params(id: f_obj.id, per_page: 1)
      assert_response :success
      assert JSON.parse(response.body).count == 1
      get :topics, construct_params(id: f_obj.id, per_page: 1, page: 2)
      assert_response :success
      assert JSON.parse(response.body).count == 1
      get :topics, construct_params(id: f_obj.id, per_page: 1, page: 3)
      assert_response :success
      assert JSON.parse(response.body).count == 1
    end

    def test_topics_with_pagination_exceeds_limit
      40.times do
        create_test_topic(f_obj, User.first)
      end
      get :topics, construct_params(id: f_obj.id, per_page: 40)
      assert_response :success
      assert JSON.parse(response.body).count == 30
    end

    def test_before_filters_follow_not_logged_in
      @controller.stubs(:logged_in?).returns(false).once
      @controller.expects(:verify_authenticity_token).never
      @controller.expects(:check_privilege).never
      @controller.expects(:access_denied).once
      post :follow, construct_params({ id: f_obj.id }, {})
    end

    def test_before_filters_follow_logged_in
      @controller.expects(:verify_authenticity_token).never
      @controller.expects(:check_privilege).never
      @controller.expects(:access_denied).never
      post :follow, construct_params({ id: f_obj.id }, {})
    end

    def test_before_filters_unfollow_not_logged_in
      @controller.stubs(:logged_in?).returns(false).once
      @controller.expects(:verify_authenticity_token).never
      @controller.expects(:check_privilege).never
      @controller.expects(:access_denied).once
      delete :unfollow, construct_params({ id: f_obj.id }, {})
    end

    def test_before_filters_unfollow_logged_in
      @controller.expects(:verify_authenticity_token).never
      @controller.expects(:check_privilege).never
      @controller.expects(:access_denied).never
      delete :unfollow, construct_params({ id: f_obj.id }, {})
    end

    def test_before_filters_is_following_not_logged_in
      @controller.stubs(:logged_in?).returns(false).once
      @controller.expects(:verify_authenticity_token).never
      @controller.expects(:check_privilege).never
      @controller.expects(:access_denied).once
      delete :is_following, construct_params({ id: f_obj.id }, {})
    end

    def test_before_filters_is_following_logged_in
      @controller.expects(:verify_authenticity_token).never
      @controller.expects(:check_privilege).never
      @controller.expects(:access_denied).never
      delete :is_following, construct_params({ id: f_obj.id }, {})
    end

    def test_follow_invalid_forum_id
      post :follow, construct_params(id: 999)
      assert_response :not_found
    end

    def test_unfollow_invalid_forum_id
      delete :unfollow, construct_params(id: 999)
      assert_response :not_found
    end

    def test_permit_toggle_params_valid
      delete :unfollow, construct_params({ id: f_obj.id }, user_id: other_user.id)
      assert_response :no_content
      monitorship = Monitorship.where(monitorable_type: 'Forum', user_id: other_user.id, monitorable_id: f_obj.id).first
      refute monitorship.active
    end

    def test_permit_toggle_params_invalid
      delete :unfollow, construct_params({ id: f_obj.id }, user_id: @agent.id)
      assert_response :bad_request
      match_json([bad_request_error_pattern('user_id/email', 'invalid_user')])
    end

    def test_follow_user_id_invalid
      post :follow, construct_params({ id: f_obj.id }, user_id: 999)
      assert_response :bad_request
      match_json [bad_request_error_pattern('user', "can't be blank")]
    end

    def test_new_monitor_follow_user_id_valid
      user = user_without_monitorships
      post :follow, construct_params({ id: f_obj.id }, user_id: user.id)
      assert_response :no_content
      monitorship = Monitorship.where(monitorable_type: 'Forum', user_id: user.id, monitorable_id: f_obj.id).first
      assert monitorship.active
    end

    def test_new_monitor_unfollow_user_id_invalid
      delete :unfollow, construct_params({ id: f_obj.id }, user_id: 999)
      assert_response :bad_request
      match_json [bad_request_error_pattern('user', "can't be blank")]
    end

    def test_is_following_without_user_id
      monitor_topic(f_obj, @agent, 1)
      get :is_following, construct_params(id: f_obj.id)
      assert_response :no_content
    end

    def test_is_following_with_user_id
      user = user_without_monitorships
      monitor_forum(f_obj, user, 1)
      get :is_following, construct_params(user_id: user.id, id: f_obj.id)
      assert_response :no_content
    end

    def test_is_following_without_privilege_invalid
      @controller.stubs(:privilege?).with(:manage_forums).returns(false)
      user = user_without_monitorships
      monitor_forum(f_obj, user, 1)
      get :is_following, construct_params(user_id: user.id, id: f_obj.id)
      match_json([bad_request_error_pattern('user_id/email', 'invalid_user')])
    end

    def test_is_following_without_privilege_valid
      @controller.stubs(:privilege?).with(:manage_forums).returns(false)
      monitor_forum(f_obj, @agent, 1)
      get :is_following, construct_params(user_id: @agent.id, id: f_obj.id)
      assert_response :no_content
    end

    def test_is_following_non_numeric_user_id
      get :is_following, construct_params(user_id: 'test', id: f_obj.id)
      assert_response :bad_request
      match_json([bad_request_error_pattern('user_id', 'is not a number')])
    end

    def test_is_following_invalid_topic_id
      get :is_following, construct_params(user_id: @agent.id, id: 8_908_908)
      assert_response :not_found
    end

    def test_is_following_invalid_user_id
      get :is_following, construct_params(user_id: user_without_monitorships.id, id: f_obj.id)
      assert_response :not_found
    end
  end
end
