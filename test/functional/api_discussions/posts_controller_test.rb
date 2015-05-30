require_relative '../../test_helper'

module ApiDiscussions
  class PostsControllerTest < ActionController::TestCase
    def wrap_cname(params)
      { post: params }
    end

    def post_obj
      Post.first
    end

    def topic_obj
      Topic.first || create_test_topic(Forum.first)
    end

    def customer
      User.where('id != ? and helpdesk_agent = ?', @agent.id, false).first || create_dummy_customer
    end

    def agent
      User.where('id != ? and helpdesk_agent = ?', @agent.id, true).first || add_test_agent
    end

    def test_update
      post = quick_create_post
      put :update, construct_params({ id: post.id }, body_html: 'test reply 2', answer: 1)
      assert_response :success
      match_json(post_pattern({ body_html: 'test reply 2', answer: true }, post.reload))
    end

    def test_update_blank_message
      post = post_obj
      put :update, construct_params({ id: post.id }, body_html: '')
      assert_response :bad_request
      match_json([bad_request_error_pattern('body_html', "can't be blank")])
    end

    def test_update_invalid_answer
      post = post_obj
      put :update, construct_params({ id: post.id }, body_html: 'test reply 2', answer: 90)
      assert_response :bad_request
      match_json([bad_request_error_pattern('answer', 'is not included in the list', list: '0,false,1,true')])
    end

    def test_update_with_user_id
      post =  post_obj
      put :update, construct_params({ id: post.id }, body_html: 'test reply 2', user_id: User.first)
      assert_response :bad_request
      match_json([bad_request_error_pattern('user_id', 'invalid_field')])
    end

    def test_update_with_topic_id
      post =  post_obj
      put :update, construct_params({ id: post.id }, body_html: 'test reply 2', topic_id: topic_obj)
      assert_response :bad_request
      match_json([bad_request_error_pattern('topic_id', 'invalid_field')])
    end

    def test_update_with_extra_params
      post =  post_obj
      put :update, construct_params({ id: post.id }, topic_id: topic_obj, created_at: Time.zone.now.to_s, 
                   updated_at: Time.zone.now.to_s, email:  Faker::Internet.email, user_id: customer.id)
      assert_response :bad_request
      match_json([bad_request_error_pattern('topic_id', 'invalid_field'),
        bad_request_error_pattern('created_at', 'invalid_field'),
        bad_request_error_pattern('updated_at', 'invalid_field'),
        bad_request_error_pattern('email', 'invalid_field'),
        bad_request_error_pattern('user_id', 'invalid_field')])
    end

    def test_update_with_nil_values
      post =  post_obj
      put :update, construct_params({ id: post.id }, body_html: nil)
      assert_response :bad_request
      match_json([bad_request_error_pattern('body_html', "can't be blank")])
    end

    def test_destroy
      post = quick_create_post
      delete :destroy, construct_params(id: post.id)
      assert_equal ' ', @response.body
      assert_response :no_content
      assert_nil Post.find_by_id(post.id)
    end

    def test_destroy_invalid_id
      delete :destroy, construct_params(id: (1000 + Random.rand(11)))
      assert_equal ' ', @response.body
      assert_response :not_found
    end

    def test_create_no_params
      post :create, construct_params({}, {})
      assert_response :bad_request
      match_json [bad_request_error_pattern('body_html', "can't be blank"),
                  bad_request_error_pattern('topic_id', 'is not a number')]
    end

    def test_create_mandatory_params
      topic = topic_obj
      post :create, construct_params({}, body_html: 'test', topic_id: topic.id)
      assert_response :created
      match_json(post_pattern(Post.last))
      match_json(post_pattern({ body_html: 'test', topic_id: topic.id,
                                user_id: @agent.id }, Post.last))
    end

    def test_create_returns_location_header
      post :create, construct_params({}, :body_html => 'test', 'topic_id' => topic_obj.id)
      assert_response :created
      match_json(post_pattern(Post.last))
      match_json(post_pattern({ body_html: 'test', topic_id: topic_obj.id,
                                user_id: @agent.id }, Post.last))
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/discussions/posts/#{result['id']}", response.headers['Location']
    end

    def test_create_customer_user
      topic_obj.update_column(:locked, false)
      user = customer
      created_at = 2.days.ago.to_s
      updated_at = 1.days.ago.to_s
      params = { :body_html => 'test', 'topic_id' => topic_obj.id,
                 'user_id' => user.id, :answer => 1, :created_at => created_at, :updated_at => updated_at }
      post :create, construct_params({}, params)
      assert_response :created
      match_json(post_pattern(Post.last))
      match_json(post_pattern(params, Post.last))
    end

    def test_create_customer_user_topic_locked
      user = customer
      topic_obj.update_column(:locked, true)
      post :create, construct_params({}, :body_html => 'test', 'topic_id' => topic_obj.id,
                                         'user_id' => user.id)
      assert_response :bad_request
      match_json([bad_request_error_pattern('user_id/email', 'invalid_user')])
      topic_obj.update_column(:locked, false)
    end

    def test_create_agent_email_topic_locked
      user = agent
      controller.class.any_instance.stubs(:is_allowed_to_assume?).returns(true)
      topic_obj.update_column(:locked, true)
      params = { :body_html => 'test', 'topic_id' => topic_obj.id,
                 'email' => user.email }
      post :create, construct_params({}, params)
      match_json(post_pattern(Post.last))
      match_json(post_pattern(params, Post.last))
      assert_response :created
      topic_obj.update_column(:locked, false)
      controller.class.any_instance.unstub(:is_allowed_to_assume?)
    end

    def test_create_invalid_model
      topic_obj.update_column(:locked, true)
      post :create, construct_params({}, :body_html => 'test', 'topic_id' => 999)
      assert_response :bad_request
      match_json([bad_request_error_pattern('topic', "can't be blank")])
    end

    def test_create_invalid_user
      post :create, construct_params({}, :body_html => 'test', 'topic_id' => topic_obj.id,
                                         'user_id' => 999)
      assert_response :bad_request
      match_json([bad_request_error_pattern('user', "can't be blank")])
    end

    def test_create_without_view_admin_privilege
      controller.class.any_instance.stubs(:privilege?).with(:all).returns(true).once
      controller.class.any_instance.stubs(:privilege?).with(:view_admin).returns(false).once
      controller.class.any_instance.stubs(:privilege?).with(:manage_users).returns(true).once
      post :create, construct_params({}, :body_html => 'test', 'topic_id' => topic_obj.id,
                                         'created_at' => Time.zone.now)
      assert_response :bad_request
      match_json([bad_request_error_pattern('created_at', 'invalid_field')])
    end

    def test_create_without_manage_users_privilege
      controller.class.any_instance.stubs(:privilege?).with(:all).returns(true).once
      controller.class.any_instance.stubs(:privilege?).with(:view_admin).returns(true).once
      controller.class.any_instance.stubs(:privilege?).with(:manage_users).returns(false).once
      post :create, construct_params({}, :body_html => 'test', 'topic_id' => topic_obj.id,
                                         'user_id' => 999)
      assert_response :bad_request
      match_json([bad_request_error_pattern('user_id', 'invalid_field')])
    end

    def test_create_with_email_without_assume_privilege
      post :create, construct_params({}, :body_html => 'test', 'topic_id' => topic_obj.id,
                                         'email' => @agent.email)
      assert_response :bad_request
      match_json([bad_request_error_pattern('user_id/email', 'invalid_user')])
    end

    def test_create_with_invalid_email
      post :create, construct_params({}, :body_html => 'test', 'topic_id' => topic_obj.id,
                                         'email' => 'random')
      assert_response :bad_request
      match_json([bad_request_error_pattern('user', "can't be blank")])
    end

    def test_create_with_user_without_assume_privilege
      post :create, construct_params({}, :body_html => 'test', 'topic_id' => topic_obj.id,
                                         'user_id' => @agent.id)
      assert_response :bad_request
      match_json([bad_request_error_pattern('user_id/email', 'invalid_user')])
    end

    def test_create_with_invalid_user_id
      post :create, construct_params({}, :body_html => 'test', 'topic_id' => topic_obj.id,
                                         'user_id' => '999')
      assert_response :bad_request
      match_json([bad_request_error_pattern('user', "can't be blank")])
    end
  end
end
