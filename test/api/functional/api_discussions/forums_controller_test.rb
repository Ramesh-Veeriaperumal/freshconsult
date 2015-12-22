require_relative '../../test_helper'

module ApiDiscussions
  class ForumsControllerTest < ActionController::TestCase
    include Helpers::DiscussionsTestHelper

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
      assert_response 204
      assert_nil Forum.find_by_id(forum.id)
    end

    def test_destroy_invalid_id
      delete :destroy, construct_params(id: (1000 + Random.rand(11)))
      assert_equal ' ', @response.body
      assert_response :missing
    end

    def test_update
      fc = fc_obj
      forum = create_test_forum(fc)
      put :update, construct_params({ id: forum.id }, forum_type: 2)
      assert_response 200
      match_json(forum_pattern(forum.reload))
      match_json(forum_response_pattern(forum, forum_type: 2))
    end

    def test_update_blank_name
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({ id: forum.id }, name: ' ')
      assert_response 400
      match_json([bad_request_error_pattern('name', :"can't be blank")])
    end

    def test_update_invalid_forum_type
      fc = fc_obj
      forum = create_test_forum(fc)
      put :update, construct_params({ id: forum.id }, forum_type: 7897)
      assert_response 400
      match_json([bad_request_error_pattern('forum_type', :not_included, list: '1,2,3,4')])
    end

    def test_update_invalid_forum_visibility
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({ id: forum.id }, forum_visibility: 7897)
      assert_response 400
      match_json([bad_request_error_pattern('forum_visibility', :not_included, list: '1,2,3,4')])
    end

    def test_update_duplicate_name
      fc = fc_obj
      forum = create_test_forum(fc)
      another_forum = create_test_forum(fc)
      put :update, construct_params({ id: forum.id }, name: another_forum.name)
      assert_response 409
      match_json([bad_request_error_pattern('name', :"already exists in the selected category")])
    end

    def test_update_unexpected_fields
      fc = fc_obj
      forum = f_obj
      another_forum = create_test_forum(fc)
      put :update, construct_params({ id: forum.id }, junk: another_forum.name)
      assert_response 400
      match_json([bad_request_error_pattern('junk', :invalid_field)])
    end

    def test_update_missing_fields
      fc = fc_obj
      forum = f_obj
      put :update, construct_params({ id: forum.id }, {})
      assert_response 400
      match_json(request_error_pattern(:missing_params))
    end

    def test_update_invalid_forum_category_id
      fc = fc_obj
      fc.update_column(:account_id, 999)
      forum = f_obj
      put :update, construct_params({ id: forum.id }, forum_category_id: fc.reload.id)
      fc.update_column(:account_id, @account.id)
      assert_response 400
      match_json([bad_request_error_pattern('forum_category_id', :"can't be blank")])
    end

    def test_update_invalid_customer_id
      fc = fc_obj
      forum = f_obj
      customer = company
      put :update, construct_params({ id: forum.id }, forum_visibility: 4, company_ids: [customer.id, 67, 78])
      assert_response 400
      match_json([bad_request_error_pattern('company_ids', :invalid_list, list: '67, 78')])
    end

    def test_update_with_customer_id
      fc = fc_obj
      forum = f_obj
      customer = company
      put :update, construct_params({ id: forum.id }, forum_visibility: 4, company_ids: [customer.id])
      assert_response 200
      pattern = forum_pattern(forum.reload).merge(company_ids: [customer.id])
      match_json(pattern)
      pattern = forum_response_pattern(forum, forum_visibility: 4).merge(company_ids: [customer.id])
      match_json(pattern)
    end

    def test_update_with_forum_visibility_company_users
      fc = fc_obj
      forum = create_test_forum(fc)
      put :update, construct_params({ id: forum.id }, forum_visibility: 4)
      assert_response 200
      pattern = forum_pattern(forum.reload).merge(company_ids: [])
      match_json(pattern)
      pattern = forum_response_pattern(forum, forum_visibility: 4).merge(company_ids: [])
      match_json(pattern)
    end

    def test_update_validate_length
      fc = fc_obj
      forum = create_test_forum(fc)
      put :update, construct_params({ id: forum.id }, name: Faker::Lorem.characters(300), description: Faker::Lorem.characters(300))
      match_json([bad_request_error_pattern('name', :"is too long (maximum is 255 characters)"),
                  bad_request_error_pattern('description', :"is too long (maximum is 255 characters)")])
      assert_response 400
    end

    def test_update_validate_length_with_trailing_spaces
      fc = fc_obj
      forum = create_test_forum(fc)
      params = { name: Faker::Lorem.characters(20) + white_space, description: Faker::Lorem.characters(20) + white_space }
      put :update, construct_params({ id: forum.id }, params)
      match_json(forum_pattern(forum.reload))
      match_json(forum_response_pattern(forum, params.each { |x, y| y.strip! if [:name, :description].include?(x) }))
      assert_response 200
    end

    def test_create_validate_presence
      post :create, construct_params({ id: ForumCategory.first.id }, description: 'test')
      match_json([bad_request_error_pattern('name', :missing_field),
                  bad_request_error_pattern('forum_visibility', :required_and_inclusion, list: '1,2,3,4'),
                  bad_request_error_pattern('forum_type', :required_and_inclusion, list: '1,2,3,4')])
      assert_response 400
    end

    def test_create_validate_inclusion
      post :create, construct_params({ id: ForumCategory.first.id }, name: 'test', forum_visibility: '9', forum_type: '89')
      match_json([bad_request_error_pattern('forum_visibility', :not_included, list: '1,2,3,4'),
                  bad_request_error_pattern('forum_type', :not_included, list: '1,2,3,4')])
      assert_response 400
    end

    def test_create_validate_length
      post :create, construct_params({ id: ForumCategory.first.id }, forum_visibility: 1, forum_type: 1, name: Faker::Lorem.characters(300), description: Faker::Lorem.characters(300))
      match_json([bad_request_error_pattern('name', :"is too long (maximum is 255 characters)"),
                  bad_request_error_pattern('description', :"is too long (maximum is 255 characters)")])
      assert_response 400
    end

    def test_create_validate_length_with_trailing_space
      params = { forum_visibility: 1, forum_type: 1, name: Faker::Lorem.characters(20) + white_space, description: Faker::Lorem.characters(20) + white_space }
      post :create, construct_params({ id: ForumCategory.first.id }, params)
      match_json(forum_pattern Forum.last)
      match_json(forum_response_pattern Forum.last, params.each { |x, y| y.strip! if [:name, :description].include?(x) })
      assert_response 201
    end

    def test_create
      post :create, construct_params({ id: ForumCategory.first.id }, description: 'desc', forum_visibility: 1,
                                                                     forum_type: 1, name: 'test')
      match_json(forum_pattern Forum.last)
      match_json(forum_response_pattern Forum.last, description: 'desc', forum_visibility: 1, forum_type: 1, name: 'test', forum_category_id: ForumCategory.first.id)
      assert_response 201
    end

    def test_create_no_params
      post :create, construct_params(id: ForumCategory.first.id)
      match_json([bad_request_error_pattern('name', :missing_field),
                  bad_request_error_pattern('forum_visibility', :required_and_inclusion, list: '1,2,3,4'),
                  bad_request_error_pattern('forum_type', :required_and_inclusion, list: '1,2,3,4')])
      assert_response 400
    end

    def test_create_invalid_forum_category_id
      post :create, construct_params(id: 5_646_456)
      assert_response :missing
    end

    def test_create_with_visibility_company_users
      name = Faker::Name.name
      fc = ForumCategory.first
      post :create, construct_params({ id: fc.id }, description: 'desc', forum_visibility: 4,
                                                    forum_type: 1, name: name)
      pattern = forum_pattern(Forum.last).merge(company_ids: [])
      match_json(pattern)
      pattern = forum_response_pattern(Forum.last, description: 'desc', forum_visibility: 4,
                                                   forum_type: 1, name: name, forum_category_id: fc.id).merge(company_ids: [])
      match_json(pattern)
      assert_response 201
    end

    def test_create_returns_location_header
      name = Faker::Name.name
      forum_category_id =  ForumCategory.first.id
      post :create, construct_params({ id: forum_category_id }, description: 'desc', forum_visibility: 1,
                                                                forum_type: 1, name: name)
      match_json(forum_pattern Forum.last)
      match_json(forum_response_pattern Forum.last, description: 'desc', forum_visibility: 1, forum_type: 1, name: name, forum_category_id: forum_category_id)
      assert_response 201
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/discussions/forums/#{result['id']}", response.headers['Location']
    end

    def test_create_invalid_customer_id
      fc = fc_obj
      customer = company
      post :create, construct_params({ id: fc.id }, description: 'desc', forum_visibility: 4, forum_type: 1,
                                                    name: 'customer test', company_ids: [customer.id, 67, 78])
      assert_response 400
      match_json([bad_request_error_pattern('company_ids', :invalid_list, list: '67, 78')])
    end

    def test_create_with_customer_id
      fc = fc_obj
      customer = company
      params = { description: 'desc', forum_visibility: 4, forum_type: 1, name: 'customer test 2', company_ids: [customer.id] }
      post :create, construct_params({ id: ForumCategory.first.id }, params)
      assert_response 201
      pattern = forum_pattern(Forum.last.reload)
      pattern[:company_ids] = [customer.id]
      match_json(pattern)
      pattern = forum_response_pattern(Forum.last, params)
      pattern[:company_ids] = [customer.id]
      match_json(pattern)
      assert_equal Forum.last.customer_forums.map(&:customer_id), [customer.id]
    end

    def test_create_with_customer_id_and_visibility_not_company_users
      fc = fc_obj
      customer = company
      params = { description: 'desc', forum_visibility: 1, forum_type: 1, name: 'customer test 2', company_ids: [customer.id] }
      post :create, construct_params({ id: ForumCategory.first.id }, params)
      match_json([bad_request_error_pattern('company_ids', :invalid_field)])
      assert_response 400
    end

    def test_update_with_customer_id_and_visibility_not_company_users
      fc = fc_obj
      forum = f_obj
      customer = company
      put :update, construct_params({ id: forum.id }, forum_visibility: 1, company_ids: [customer.id])
      match_json([bad_request_error_pattern('company_ids', :invalid_field)])
      assert_response 400
    end

    def test_create_with_customer_id_and_visibility_invalid
      fc = fc_obj
      customer = company
      params = { description: 'desc', forum_visibility: 'x', forum_type: 1, name: Faker::Name.name, company_ids: [customer.id] }
      post :create, construct_params({ id: ForumCategory.first.id }, params)
      match_json([bad_request_error_pattern('forum_visibility', :not_included, list: '1,2,3,4')])
      assert_response 400
    end

    def test_update_with_customer_id_and_visibility_invalid
      fc = fc_obj
      forum = f_obj
      customer = company
      put :update, construct_params({ id: forum.id }, forum_visibility: 'x', company_ids: "#{customer.id}")
      match_json([bad_request_error_pattern('forum_visibility', :not_included, list: '1,2,3,4')])
      assert_response 400
    end

    def test_create_with_customer_id_invalid_data_type
      fc = fc_obj
      customer = company
      params = { description: 'desc', forum_visibility: 4, forum_type: 1, name: Faker::Name.name, company_ids: "#{customer.id}" }
      post :create, construct_params({ id: ForumCategory.first.id }, params)
      match_json([bad_request_error_pattern('company_ids', :data_type_mismatch, data_type: 'Array')])
      assert_response 400
    end

    def test_update_with_customer_id_invalid_data_type
      fc = fc_obj
      forum = f_obj
      customer = company
      put :update, construct_params({ id: forum.id }, forum_visibility: 4, company_ids: "#{customer.id}")
      match_json([bad_request_error_pattern('company_ids', :data_type_mismatch, data_type: 'Array')])
      assert_response 400
    end

    def test_update_with_customer_id_and_visibility_valid
      customer = company
      forum = create_test_forum(fc_obj, 1, 1)
      put :update, construct_params({ id: forum.id }, forum_visibility: 4, company_ids: [customer.id])
      assert_response 200
      pattern = forum_pattern(forum.reload).merge(company_ids: [customer.id])
      match_json(pattern)
      pattern = forum_response_pattern(forum, forum_visibility: 4).merge(company_ids: [customer.id])
      match_json(pattern)
      assert_equal forum.customer_forums.map(&:customer_id), [customer.id]
    end

    def test_update_with_nil_values
      fc = fc_obj
      forum = create_test_forum(fc_obj)
      customer = company
      put :update, construct_params({ id: forum.id }, forum_visibility: nil, forum_type: nil, forum_category_id: nil, name: nil)
      pattern = [bad_request_error_pattern('name', :"can't be blank"),
                 bad_request_error_pattern('forum_category_id', :required_and_numericality),
                 bad_request_error_pattern('forum_visibility', :not_included, list: '1,2,3,4'),
                 bad_request_error_pattern('forum_type', :not_included, list: '1,2,3,4')]
      match_json(pattern)
      assert_response 400
    end

    def test_update_with_forum_type_with_more_topics
      fc = fc_obj
      forum = create_test_forum(fc)
      topic = create_test_topic(forum)
      put :update, construct_params({ id: forum.id }, forum_type: 2)
      pattern = [bad_request_error_pattern('forum_type', :invalid_field)]
      match_json(pattern)
      assert_response 400
    end

    def test_before_filters_show
      controller.class.any_instance.expects(:check_privilege).once
      get :show, construct_params(id: 1)
    end

    def test_create_extra_params
      post :create, construct_params({ id: ForumCategory.first.id }, account_id: 1, test: 2)
      match_json([bad_request_error_pattern('account_id', :invalid_field), bad_request_error_pattern('test', :invalid_field)])
      assert_response 400
    end

    def test_create_invalid_model
      fc = fc_obj
      forum = create_test_forum(fc)
      post :create, construct_params({ id: fc.id }, forum_visibility: 1, forum_type: 1, name: forum.name)
      match_json([bad_request_error_pattern('name', :"already exists in the selected category")])
      assert_response 409
    end

    def test_show_invalid_id
      get :show, construct_params(id: 'x')
      assert_response :missing
      assert_equal ' ', @response.body
    end

    def test_show
      f = Forum.first
      get :show, construct_params(id: f.id)
      pattern = forum_pattern(f)
      assert_response 200
      match_json(pattern)
    end

    def test_update_with_customers
      forum = Forum.first
      forum_visibility = forum.forum_visibility
      forum.update_column(:forum_visibility, 4)
      put :update, construct_params({ id: forum.id }, description: 'new description')
      assert_response 200
      result_pattern = forum_pattern(forum.reload)
      result_pattern[:company_ids] = []
      forum.customer_forums.each do |cf|
        result_pattern[:company_ids] << cf.customer_id
      end
      match_json(result_pattern)
      forum.update_column(:forum_visibility, forum_visibility)
    end

    def test_create_with_customers
      post :create, construct_params({ id: ForumCategory.first.id }, description: 'desc', forum_visibility: 4,
                                                                     forum_type: 1, name: 'test new name')
      forum = Forum.last
      result_pattern = forum_pattern(forum)
      result_pattern[:company_ids] = []
      forum.customer_forums.each do |cf|
        result_pattern[:company_ids] << cf.customer_id
      end
      match_json(result_pattern)
      assert_response 201
    end

    def test_before_filters_follow_logged_in
      @controller.expects(:check_privilege).once
      @controller.expects(:access_denied).never
      post :follow, construct_params({ id: f_obj.id }, {})
    end

    def test_before_filters_unfollow_logged_in
      @controller.expects(:check_privilege).once
      @controller.expects(:access_denied).never
      delete :unfollow, controller_params(id: f_obj.id)
    end

    def test_before_filters_is_following_logged_in
      @controller.expects(:check_privilege).once
      @controller.expects(:access_denied).never
      get :is_following, controller_params(id: f_obj.id)
    end

    def test_follow_invalid_forum_id
      post :follow, construct_params(id: 999)
      assert_response :missing
    end

    def test_unfollow_invalid_forum_id
      delete :unfollow, controller_params(id: 999)
      assert_response :missing
    end

    def test_permit_toggle_params_valid
      Monitorship.where(monitorable_type: 'Forum', user_id: @agent.id,
                        monitorable_id: f_obj.id).first || monitor_forum(f_obj, @agent, 1)
      delete :unfollow, controller_params(id: f_obj.id, user_id: other_user.id)
      assert_response 204
      monitorship = Monitorship.where(monitorable_type: 'Forum', user_id: other_user.id, monitorable_id: f_obj.id).first
      refute monitorship.active
    end

    def test_permit_toggle_params_deleted_user
      Monitorship.where(monitorable_type: 'Forum', user_id: deleted_user.id,
                        monitorable_id: f_obj.id).first || monitor_forum(f_obj, deleted_user, 1)
      delete :unfollow, controller_params(id: f_obj.id, user_id: deleted_user.id)
      assert_response 204
      deleted_user.update_column(:deleted, false)
    end

    def test_follow_user_id_invalid
      post :follow, construct_params({ id: f_obj.id }, user_id: 999)
      assert_response 400
      match_json [bad_request_error_pattern('user_id', :"can't be blank")]
    end

    def test_new_monitor_follow_user_id_valid
      user = user_without_monitorships
      post :follow, construct_params({ id: f_obj.id }, user_id: user.id)
      assert_response 204
      monitorship = Monitorship.where(monitorable_type: 'Forum', user_id: user.id, monitorable_id: f_obj.id).first
      assert monitorship.active
    end

    def test_new_monitor_follow_user_id_invalid
      post :follow, construct_params({ id: f_obj.id }, user_id: 999)
      assert_response 400
      match_json [bad_request_error_pattern('user_id', :"can't be blank")]
    end

    def test_is_following_without_user_id
      monitor_topic(f_obj, @agent, 1)
      get :is_following, controller_params(id: f_obj.id)
      assert_response 204
    end

    def test_is_following_with_user_id
      user = user_without_monitorships
      monitor_forum(f_obj, user, 1)
      get :is_following, controller_params(user_id: user.id, id: f_obj.id)
      assert_response 204
    end

    def test_is_following_without_privilege_invalid
      @controller.stubs(:privilege?).with(:manage_forums).returns(false)
      user = user_without_monitorships
      monitor_forum(f_obj, user, 1)
      get :is_following, controller_params(user_id: user.id, id: f_obj.id)
      assert_response 403
      match_json(request_error_pattern(:access_denied, id: user.id))
      @controller.unstub(:privilege?)
    end

    def test_is_following_without_privilege_invalid_user_id
      get :is_following, controller_params({user_id: ['1'], id: f_obj.id}, false)
      assert_response 400
      match_json([bad_request_error_pattern('user_id', :invalid_field)])
    end

    def test_is_following_without_privilege_valid
      @controller.stubs(:privilege?).with(:manage_forums).returns(false)
      monitor_forum(f_obj, @agent, 1)
      get :is_following, controller_params(user_id: @agent.id, id: f_obj.id)
      assert_response 204
      @controller.unstub(:privilege?)
    end

    def test_is_following_non_numeric_user_id
      get :is_following, controller_params(user_id: 'test', id: f_obj.id)
      assert_response 400
      match_json([bad_request_error_pattern('user_id', :data_type_mismatch, data_type: 'Positive Integer')])
    end

    def test_is_following_invalid_topic_id
      get :is_following, controller_params(user_id: @agent.id, id: 8_908_908)
      assert_response :missing
    end

    def test_is_following_unexpected_fields
      get :is_following, controller_params(junk: 'test', id: f_obj.id)
      assert_response 400
      match_json([bad_request_error_pattern('junk', :invalid_field)])
    end

    def test_is_following_invalid_user_id
      get :is_following, controller_params(user_id: user_without_monitorships.id, id: f_obj.id)
      assert_response :missing
    end

    def test_category_forums
      get :category_forums, controller_params(id: fc_obj.id)
      assert_response 200
      result_pattern = []
      fc_obj.forums.each do |f|
        result_pattern << forum_pattern(f)
      end
      match_json(result_pattern.ordered!)
    end

    def test_category_forums_invalid_id
      get :category_forums, controller_params(id: 'x')
      assert_response :missing
      assert_equal ' ', @response.body
    end

    def test_category_forums_with_pagination
      3.times do
        create_test_forum(fc_obj)
      end
      get :category_forums, controller_params(id: fc_obj.id, per_page: 1)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      get :category_forums, controller_params(id: fc_obj.id, per_page: 1, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      get :category_forums, controller_params(id: fc_obj.id, per_page: 1, page: 3)
      assert_response 200
      assert JSON.parse(response.body).count == 1
    end

    def test_category_forums_with_pagination_exceeds_limit
      category = fc_obj
      get :category_forums, controller_params(id: category.id, per_page: 101)
      assert_response 400
      match_json([bad_request_error_pattern('per_page', :gt_zero_lt_max_per_page, data_type: 'Positive Integer')])
    end

    def test_category_forums_with_link_header
      fc  = create_test_category
      3.times do
        create_test_forum(fc)
      end
      get :category_forums, controller_params(id: fc.id,  per_page: 2)
      assert_response 200
      pattern = []
      fc.forums.limit(2).each do |f|
        pattern << forum_pattern(f)
      end
      match_json(pattern.ordered!)
      assert JSON.parse(response.body).count == 2
      assert_equal "<http://#{@request.host}/api/v2/discussions/categories/#{fc.id}/forums?per_page=2&page=2>; rel=\"next\"", response.headers['Link']

      get :category_forums, controller_params(id: fc.id,  per_page: 2, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      assert_nil response.headers['Link']
    end

    # def test_update_array_field_with_empty_array
    #   fc = fc_obj
    #   forum = create_test_forum(fc)
    #   put :update, construct_params({ id: forum.id }, company_ids: [1, 2])
    #   assert_response 200
    #   put :update, construct_params({ id: forum.id }, company_ids: [])
    #   assert_response 200
    #   match_json(forum_pattern({company_ids: [] }, forum.reload))
    # end
  end
end
