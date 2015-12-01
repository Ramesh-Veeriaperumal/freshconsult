require_relative '../../test_helper'

module ApiDiscussions
  class TopicsControllerTest < ActionController::TestCase
    include Helpers::DiscussionsTestHelper

    def forum_obj
      Forum.first
    end

    def first_topic
      topic = Topic.first || create_test_topic(forum_obj)
      topic.locked = topic.locked.to_s.to_bool
      topic.published = topic.published.to_s.to_bool
      topic
    end

    def last_topic
      Topic.last
    end

    def wrap_cname(params)
      { topic: params }
    end

    def test_create
      post :create, construct_params({ id: forum_obj.id },
                                     title: 'test title', message_html: 'test content')
      match_json(topic_pattern(last_topic))
      match_json(topic_pattern({ forum_id: forum_obj.id, title: 'test title', posts_count: 1 }, last_topic))
      assert_response 201
    end

    def test_create_returns_location_header
      post :create, construct_params({ id: forum_obj.id },
                                     title: 'test title', message_html: 'test content')
      match_json(topic_pattern(last_topic))
      match_json(topic_pattern({ forum_id: forum_obj.id, title: 'test title', posts_count: 1 }, last_topic))
      assert_response 201
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/discussions/topics/#{result['id']}", response.headers['Location']
    end

    def test_create_with_stamp_type
      forum = forum_obj
      forum.update_column(:forum_type, 2)
      post :create, construct_params({ id: forum_obj.id },
                                     title: 'test title', message_html: 'test content', stamp_type: 3)
      match_json(topic_pattern({}, last_topic))
      match_json(topic_pattern({ forum_id: forum.id, title: 'test title', posts_count: 1,
                                 stamp_type: 3 }, last_topic))
      assert_response 201
    end

    def test_create_without_title
      post :create, construct_params({ id: forum_obj.id },
                                     message_html: 'test content')
      match_json([bad_request_error_pattern('title', :missing_field)])
      assert_response 400
    end

    def test_create_without_message
      post :create, construct_params({ id: forum_obj.id },
                                     title: 'test title')
      match_json([bad_request_error_pattern('message_html', :missing_field)])
      assert_response 400
    end

    def test_create_invalid_forum_id
      post :create, construct_params({ id: 33_333 }, title: 'test title',
                                                     message_html: 'test content')
      assert_response :missing
    end

    def test_create_invalid_user_field
      post :create, construct_params({ id: forum_obj.id }, title: 'test title', message_html: 'test content', user_id: (1000 + Random.rand(11)))
      match_json([bad_request_error_pattern('user_id', :invalid_field)])
      assert_response 400
    end

    def test_create_validate_numericality
      post :create, construct_params({ id: forum_obj.id },
                                     title: 'test title', message_html: 'test content', stamp_type: 'hj')
      match_json([bad_request_error_pattern('stamp_type', :data_type_mismatch, data_type: 'Positive Integer')])
      assert_response 400
    end

    def test_create_validate_inclusion
      post :create, construct_params({ id: forum_obj.id },
                                     title: 'test title', message_html: 'test content',  sticky: 'junk', locked: 'junk2')
      match_json([bad_request_error_pattern('locked', :data_type_mismatch, data_type: 'Boolean'),
                  bad_request_error_pattern('sticky', :data_type_mismatch, data_type: 'Boolean')])
      assert_response 400
    end

    def test_create_validate_length
      post :create, construct_params({ id: forum_obj.id },
                                     title: Faker::Lorem.characters(300), message_html: 'test content')
      match_json([bad_request_error_pattern('title', :"is too long (maximum is 255 characters)")])
      assert_response 400
    end

    def test_create_validate_length_with_trailing_space
      params = { title: Faker::Lorem.characters(20) + white_space, message_html: 'test content' }
      post :create, construct_params({ id: forum_obj.id }, params)
      match_json(topic_pattern(last_topic))
      match_json(topic_pattern(params.each { |x, y| y.strip! if x == :title }, last_topic))
      assert_response 201
    end

    def test_before_filters_follow_logged_in
      @controller.expects(:check_privilege).once
      @controller.expects(:access_denied).never
      post :follow, construct_params({ id: first_topic.id }, {})
    end

    def test_before_filters_unfollow_logged_in
      @controller.expects(:check_privilege).once
      @controller.expects(:access_denied).never
      delete :unfollow, controller_params(id: first_topic.id)
    end

    def test_before_filters_is_following_logged_in
      @controller.expects(:check_privilege).once
      @controller.expects(:access_denied).never
      get :is_following, controller_params(id: first_topic.id)
    end

    def test_before_filters_followed_by_logged_in
      @controller.expects(:check_privilege).once
      @controller.expects(:access_denied).never
      get :followed_by, request_params
    end

    def test_follow_invalid_topic_id
      post :follow, construct_params({ id: 999 }, {})
      assert_response :missing
    end

    def test_unfollow_invalid_topic_id
      delete :unfollow, controller_params(id: 999)
      assert_response :missing
    end

    def test_is_following_invalid_topic_id
      get :is_following, controller_params(id: 999)
      assert_response :missing
    end

    def test_permit_toggle_params_valid
      user = other_user
      monitorship = Monitorship.where(monitorable_type: 'Topic', user_id: user.id,
                                      monitorable_id: first_topic.id).first || monitor_topic(first_topic, user, 1)
      delete :unfollow, controller_params(id: first_topic.id, user_id: user.id)
      assert_response 204
      monitorship.reload
      refute monitorship.active
    end

    def test_unfollow_user_id_invalid
      monitor_topic(first_topic, other_user, 1)
      delete :unfollow, controller_params(id: first_topic.id, user_id: 908_989)
      assert_response :missing
    end

    def test_unfollow_valid_params_invalid_record
      monitor = Monitorship.where(monitorable_type: 'Topic').last
      user = User.find_by_id(monitor.user_id)
      email = user.email
      user.update_column(:email, nil)
      delete :unfollow, controller_params(id: monitor.monitorable_id, user_id: user.id)
      assert_response 400
      user.update_column(:email, email)
    end

    def test_permit_toggle_params_deleted_user
      monitor_topic(first_topic, deleted_user, 1)
      delete :unfollow, controller_params(id: first_topic.id, user_id: deleted_user.id)
      assert_response 204
      deleted_user.update_column(:deleted, false)
    end

    def test_follow_user_id_invalid
      post :follow, construct_params({ id: first_topic.id }, user_id: 999)
      assert_response 400
      match_json [bad_request_error_pattern('user_id', :"can't be blank")]
    end

    def test_new_monitor_follow_user_id_valid
      topic = first_topic
      user = user_without_monitorships
      post :follow, construct_params({ id: topic.id }, user_id: user.id)
      assert_response 204
      monitorship = Monitorship.where(monitorable_type: 'Topic', user_id: user.id,
                                      monitorable_id: topic.id).first
      assert monitorship.active
    end

    def test_new_monitor_follow_user_id_invalid
      post :follow, construct_params({ id: first_topic.id }, user_id: 999)
      assert_response 400
      match_json [bad_request_error_pattern('user_id', :"can't be blank")]
    end

    def test_show
      topic = create_test_topic(forum_obj)
      get :show, construct_params(id: topic.id)
      result_pattern = topic_pattern(topic)
      match_json(result_pattern)
      assert_response 200
    end

    def test_show_invalid_id
      get :show, construct_params(id: (1000 + Random.rand(11)))
      assert_response :missing
      assert_equal ' ', @response.body
    end

    def test_update_without_edit_topic_privilege
      topic = first_topic
      User.any_instance.stubs(:privilege?).with(:edit_topic).returns(false).once
      put :update, construct_params({ id: topic }, sticky: !topic.sticky)
      assert_response 403
    end

    def test_update_with_email
      topic = first_topic
      put :update, construct_params({ id: topic }, email: 'test@test.com')
      assert_response 400
      match_json([bad_request_error_pattern('email', :invalid_field)])
    end

    def test_update_with_no_params
      put :update, construct_params({ id: first_topic.id }, {})
      assert_response 400
      match_json(request_error_pattern(:missing_params))
    end

    def test_destroy
      topic = first_topic
      delete :destroy, construct_params(id: topic.id)
      assert_equal ' ', @response.body
      assert_response 204
      assert_nil Topic.find_by_id(topic.id)
    end

    def test_destroy_invalid_id
      delete :destroy, construct_params(id: (1000 + Random.rand(11)))
      assert_equal ' ', @response.body
      assert_response :missing
    end

    def test_update
      forum = Forum.where(forum_type: 2).first
      topic = first_topic
      params = { title: 'New', message_html: 'New msg',
                 stamp_type: Topic::FORUM_TO_STAMP_TYPE[forum.forum_type].last,
                 sticky: !topic.sticky, locked: !topic.locked, forum_id: forum.id }
      put :update, construct_params({ id: topic.id }, params)
      match_json(topic_pattern(topic.reload))
      match_json(topic_pattern(params, topic))
      assert_response 200
    end

    def test_update_with_invalid_stamp_type
      forum = first_topic.forum
      forum.update_column(:forum_type, 2)
      allowed = Topic::FORUM_TO_STAMP_TYPE[forum.forum_type]
      allowed_string = allowed.join(',')
      allowed_string += 'null' if allowed.include?(nil)
      put :update, construct_params({ id: first_topic.id }, stamp_type: 78)
      match_json([bad_request_error_pattern('stamp_type', :allowed_stamp_type, list: allowed_string)])
      assert_response 400
    end

    def test_update_with_invalid_question_stamp_type
      topic = first_topic
      forum = topic.forum
      forum.update_column(:forum_type, 1)
      unless topic.answer
        post = create_test_post(topic, @agent)
        post.update_column(:answer, true)
      end
      put :update, construct_params({ id: topic.id }, stamp_type: 7)
      match_json([bad_request_error_pattern('stamp_type', :allowed_stamp_type, list: '6')])
      assert_response 400

      topic.posts.update_all(answer: false)
      put :update, construct_params({ id: topic.id }, stamp_type: 6)
      match_json([bad_request_error_pattern('stamp_type', :allowed_stamp_type, list: '7')])
      assert_response 400
    end

    def test_update_without_title
      put :update, construct_params({ id: first_topic.id }, title: '')
      match_json([bad_request_error_pattern('title', :"can't be blank")])
      assert_response 400
    end

    def test_update_without_message
      put :update, construct_params({ id: first_topic.id }, forum_id: forum_obj.id,
                                                            message_html: '')
      match_json([bad_request_error_pattern('message_html', :"can't be blank")])
      assert_response 400
    end

    def test_update_invalid_forum_id
      put :update, construct_params({ id: first_topic.id }, forum_id: (1000 + Random.rand(11)))
      match_json([bad_request_error_pattern('forum_id', :"can't be blank")])
      assert_response 400
    end

    def test_update_invalid_title_length
      put :update, construct_params({ id: first_topic.id }, title: Faker::Lorem.characters(300))
      match_json([bad_request_error_pattern('title', :"is too long (maximum is 255 characters)")])
      assert_response 400
    end

    def test_update_valid_title_length
      topic = first_topic
      params = { title: Faker::Lorem.characters(20) + white_space }
      put :update, construct_params({ id: first_topic.id }, params)
      match_json(topic_pattern(topic.reload))
      match_json(topic_pattern(params.each { |x, y| y.strip! if x == :title }, topic))
      assert_response 200
    end

    def test_update_with_nil_values
      put :update, construct_params({ id: first_topic.id }, forum_id: nil,
                                                            title: nil, message_html: nil)
      match_json([bad_request_error_pattern('forum_id', :required_and_numericality),
                  bad_request_error_pattern('title', :"can't be blank"),
                  bad_request_error_pattern('message_html', :"can't be blank")
                 ])
      assert_response 400
    end

    def test_followed_by
      user = user_without_monitorships
      monitor_topic(create_test_topic(forum_obj), user, 1)
      @controller.stubs(:privilege?).with(:manage_forums).returns(true)
      get :followed_by, controller_params(user_id: user.id)
      assert_response 200
      result_pattern = []
      Topic.followed_by(user.id).each do |t|
        result_pattern << topic_pattern(t)
      end
      assert result_pattern.count == 1
      match_json result_pattern
    end

    def test_followed_by_pagination
      user = user_without_monitorships
      monitor_topic(create_test_topic(forum_obj), user, 1)
      @controller.stubs(:privilege?).with(:manage_forums).returns(true)
      get :followed_by, controller_params(user_id: user.id, page: 1, per_page: 1)
      assert_response 200
      result_pattern = []
      Topic.followed_by(user.id).each do |t|
        result_pattern << topic_pattern(t)
      end
      assert result_pattern.count == 1
      match_json result_pattern
    end

    def test_followed_by_invalid_id
      get :followed_by, controller_params(user_id: (1000 + Random.rand(11)))
      assert_response 200
      result_pattern = []
      match_json result_pattern
    end

    def test_followed_by_non_numeric_id
      get :followed_by, controller_params(user_id: 'test')
      assert_response 400
      match_json([bad_request_error_pattern('user_id', :data_type_mismatch, data_type: 'Positive Integer')])
    end

    def test_followed_by_without_user_id
      monitor_topic(create_test_topic(forum_obj), @agent, 1)
      get :followed_by, controller_params
      assert_response 200
      result_pattern = []
      Topic.followed_by(@agent.id).each do |t|
        result_pattern << topic_pattern(t)
      end
      match_json result_pattern
    end

    def test_followed_by_without_privilege_invalid
      @controller.stubs(:privilege?).with(:manage_forums).returns(false)
      user = user_without_monitorships
      monitor_topic(first_topic, user, 1)
      get :followed_by, controller_params(user_id: user.id)
      assert_response 403
    end

    def test_followed_by_without_privilege_valid
      @controller.stubs(:privilege?).with(:manage_forums).returns(false)
      monitor_topic(create_test_topic(forum_obj), @agent, 1)
      get :followed_by, controller_params
      assert_response 200
      result_pattern = []
      Topic.followed_by(@agent.id).each do |t|
        result_pattern << topic_pattern(t)
      end
      match_json result_pattern
    end

    def test_is_following_without_user_id
      topic = create_test_topic(forum_obj)
      monitor_topic(topic, @agent, 1)
      get :is_following, controller_params(id: topic.id)
      assert_response 204
    end

    def test_is_following_with_user_id
      topic = create_test_topic(forum_obj)
      user = user_without_monitorships
      monitor_topic(topic, user, 1)
      get :is_following, controller_params(user_id: user.id, id: topic.id)
      assert_response 204
    end

    def test_is_following_without_privilege_invalid
      user = user_without_monitorships
      monitor_topic(first_topic, user, 1)
      @controller.stubs(:privilege?).with(:manage_forums).returns(false)
      get :is_following, controller_params(user_id: user.id, id: first_topic.id)
      assert_response 403
      match_json(request_error_pattern(:access_denied, id: user.id))
      @controller.unstub(:privilege?)
    end

    def test_is_following_without_privilege_valid
      topic = create_test_topic(forum_obj)
      monitor_topic(topic, @agent, 1)
      @controller.stubs(:privilege?).with(:manage_forums).returns(false)
      get :is_following, controller_params(user_id: @agent.id, id: topic.id)
      assert_response 204
      @controller.unstub(:privilege?)
    end

    def test_is_following_non_numeric_user_id
      get :is_following, controller_params(user_id: 'test', id: first_topic.id)
      assert_response 400
      match_json([bad_request_error_pattern('user_id', :data_type_mismatch, data_type: 'Positive Integer')])
    end

    def test_is_following_unexpected_fields
      get :is_following, controller_params(junk: 'test', id: first_topic.id)
      assert_response 400
      match_json([bad_request_error_pattern('junk', :invalid_field)])
    end

    def test_is_following_invalid_user_id
      get :is_following, controller_params(user_id: user_without_monitorships.id, id: first_topic.id)
      assert_response :missing
    end

    def test_topics_invalid_id
      get :forum_topics, construct_params(id: 'x')
      assert_response :missing
      assert_equal ' ', @response.body
    end

    def test_topics
      f = Forum.where('topics_count >= ?', 1).first || create_test_topic(Forum.first, User.first).forum
      3.times do
        create_test_topic(f, User.first)
      end
      get :forum_topics, construct_params(id: f.id)
      result_pattern = []
      f.topics.newest.each do |t|
        result_pattern << topic_pattern(t)
      end
      assert_response 200
      match_json(result_pattern.ordered!)
    end

    def test_topics_with_pagination
      3.times do
        create_test_topic(forum_obj, User.first)
      end
      get :forum_topics, construct_params(id: forum_obj.id, per_page: 1)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      get :forum_topics, construct_params(id: forum_obj.id, per_page: 1, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      get :forum_topics, construct_params(id: forum_obj.id, per_page: 1, page: 3)
      assert_response 200
      assert JSON.parse(response.body).count == 1
    end

    def test_topics_with_pagination_exceeds_limit
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:per_page).returns(2)
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:max_per_page).returns(3)
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:page).returns(1)
      get :forum_topics, construct_params(id: forum_obj.id, per_page: 4)
      assert_response 200
      assert JSON.parse(response.body).count == 3
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.unstub(:[])
    end

    def test_topics_with_link_header
      f = create_test_forum(ForumCategory.first)
      3.times do
        create_test_topic(f, User.first)
      end
      get :forum_topics, construct_params(id: f.id, per_page: 2)
      assert_response 200
      assert JSON.parse(response.body).count == 2
      assert_equal "<http://#{@request.host}/api/v2/discussions/forums/#{f.id}/topics?per_page=2&page=2>; rel=\"next\"", response.headers['Link']

      get :forum_topics, construct_params(id: f.id, per_page: 2, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      assert_nil response.headers['Link']
    end
  end
end
