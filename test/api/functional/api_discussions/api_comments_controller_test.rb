require_relative '../../test_helper'

module ApiDiscussions
  class ApiCommentsControllerTest < ActionController::TestCase
    include Helpers::DiscussionsTestHelper

    def wrap_cname(params)
      { api_comment: params }
    end

    def comment_obj
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

    def test_privilege_for_update
      comment = quick_create_post
      comment.update_column(:user_id, @agent.id)
      User.any_instance.stubs(:privilege?).with(:edit_topic).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_forums).returns(true)
      put :update, construct_params({ id: comment.id }, body_html: 'test reply 2', answer: true)
      assert_response 200

      comment.update_column(:user_id, 999)
      put :update, construct_params({ id: comment.id }, body_html: 'test reply 2', answer: true)
      match_json([bad_request_error_pattern('body_html', :inaccessible_field)])
      assert_response 400

      put :update, construct_params({ id: comment.id }, answer: true)
      assert_response 200

      User.any_instance.stubs(:privilege?).with(:edit_topic).returns(true)
      put :update, construct_params({ id: comment.id }, body_html: 'test reply 2', answer: true)
      assert_response 200

      comment.update_column(:user_id, @agent.id)
      User.any_instance.stubs(:privilege?).with(:view_forums).returns(false)
      User.any_instance.stubs(:privilege?).with(:edit_topic, comment).returns(true)
      put :update, construct_params({ id: comment.id }, answer: true, body_html: 'test reply 2')
      match_json([bad_request_error_pattern('answer', :inaccessible_field)])
      assert_response 400

      @controller.stubs(:api_current_user).returns(nil)
      put :update, construct_params({ id: comment.id }, answer: true, body_html: 'test reply 2')
      @controller.unstub(:api_current_user)
      match_json(request_error_pattern(:invalid_credentials))
      assert_response 401

      User.any_instance.stubs(:customer?).returns(true)
      put :update, construct_params({ id: comment.id }, answer: true, body_html: 'test reply 2')
      match_json(request_error_pattern(:access_denied))
      assert_response 403
    ensure
      User.any_instance.unstub(:privilege?)
      User.any_instance.unstub(:customer?)
      @controller.unstub(:privilege?)
      @controller.unstub(:api_current_user)
    end

    def test_update
      comment = quick_create_post
      put :update, construct_params({ id: comment.id }, body_html: 'test reply 2', answer: true)
      assert_response 200
      match_json(comment_pattern({ body_html: 'test reply 2', answer: true }, comment.reload))
    end

    def test_update_answer_non_question
      post = quick_create_post
      post.topic.update_column(:stamp_type, nil)
      put :update, construct_params({ id: post.id }, body_html: 'test reply 2', answer: true)
      assert_response 400
      match_json([bad_request_error_pattern('answer', :incompatible_field)])
      post.topic.update_column(:stamp_type, 6)
    end

    def test_update_post_answer
      post = quick_create_post
      assert_equal 7, post.topic.stamp_type
      put :update, construct_params({ id: post.id }, body_html: 'test reply 2', answer: true)
      match_json(comment_pattern({ answer: true }, post.reload))
      assert_response 200
      assert_equal 6, post.topic.reload.stamp_type
      assert post.reload.answer

      other_post = post.topic.posts.create(user_id: @agent.id, body_html: 'test', forum_id: post.topic.forum_id)
      put :update, construct_params({ id: other_post.id }, body_html: 'test reply 2', answer: true)
      assert_response 200
      match_json(comment_pattern({ answer: true }, other_post.reload))
      refute post.reload.answer
      assert other_post.reload.answer

      put :update, construct_params({ id: other_post.id }, body_html: 'test reply 2', answer: false)
      match_json(comment_pattern({ answer: false }, other_post.reload))
      assert_response 200
      assert_equal 7, post.topic.reload.stamp_type
      refute other_post.reload.answer
    end

    def test_update_blank_message
      comment = comment_obj
      put :update, construct_params({ id: comment.id }, body_html: '')
      assert_response 400
      match_json([bad_request_error_pattern('body_html', :"can't be blank")])
    end

    def test_update_invalid_answer
      comment = comment_obj
      Topic.any_instance.stubs(:stamp_type).returns(6)
      put :update, construct_params({ id: comment.id }, body_html: 'test reply 2', answer: 90)
      Topic.any_instance.unstub(:stamp_type)
      assert_response 400
      match_json([bad_request_error_pattern('answer', :data_type_mismatch, data_type: 'Boolean')])
    end

    def test_update_with_user_id
      comment =  comment_obj
      put :update, construct_params({ id: comment.id }, body_html: 'test reply 2', user_id: User.first)
      assert_response 400
      match_json([bad_request_error_pattern('user_id', :invalid_field)])
    end

    def test_update_with_topic_id
      comment =  comment_obj
      put :update, construct_params({ id: comment.id }, body_html: 'test reply 2', topic_id: topic_obj)
      assert_response 400
      match_json([bad_request_error_pattern('topic_id', :invalid_field)])
    end

    def test_update_with_extra_params
      comment =  comment_obj
      put :update, construct_params({ id: comment.id }, topic_id: topic_obj, created_at: Time.zone.now.to_s,
                                                        updated_at: Time.zone.now.to_s, email:  Faker::Internet.email, user_id: customer.id)
      assert_response 400
      match_json([bad_request_error_pattern('topic_id', :invalid_field),
                  bad_request_error_pattern('created_at', :invalid_field),
                  bad_request_error_pattern('updated_at', :invalid_field),
                  bad_request_error_pattern('email', :invalid_field),
                  bad_request_error_pattern('user_id', :invalid_field)])
    end

    def test_update_with_nil_values
      comment =  comment_obj
      put :update, construct_params({ id: comment.id }, body_html: nil)
      assert_response 400
      match_json([bad_request_error_pattern('body_html', :"can't be blank")])
    end

    def test_destroy
      comment = quick_create_post
      delete :destroy, construct_params(id: comment.id)
      assert_equal ' ', @response.body
      assert_response 204
      assert_nil Post.find_by_id(comment.id)
    end

    def test_destroy_invalid_id
      delete :destroy, construct_params(id: (1000 + Random.rand(11)))
      assert_equal ' ', @response.body
      assert_response :missing
    end

    def test_create_no_params
      post :create, construct_params({ id: topic_obj.id }, {})
      assert_response 400
      match_json [bad_request_error_pattern('body_html', :missing_field)]
    end

    def test_create_mandatory_params
      topic = topic_obj
      post :create, construct_params({ id: topic.id }, body_html: 'test')
      assert_response 201
      match_json(comment_pattern(Post.last))
      match_json(comment_pattern({ body_html: 'test', topic_id: topic.id,
                                   user_id: @agent.id }, Post.last))
    end

    def test_create_returns_location_header
      topic = topic_obj
      post :create, construct_params({ id: topic.id }, body_html: 'test')
      assert_response 201
      match_json(comment_pattern(Post.last))
      match_json(comment_pattern({ body_html: 'test', topic_id: topic.id,
                                   user_id: @agent.id }, Post.last))
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/discussions/comments/#{result['id']}", response.headers['Location']
    end

    def test_create_invalid_model
      post :create, construct_params({ id: 34_234_234 }, body_html: 'test')
      assert_response :missing
    end

    def test_create_invalid_user_field
      post :create, construct_params({ id: topic_obj.id }, :body_html => 'test',
                                                           'user_id' => 999, 'answer' => true)
      assert_response 400
      match_json([bad_request_error_pattern('user_id', :invalid_field),
                  bad_request_error_pattern('answer', :invalid_field)])
    end

    def test_comments_invalid_id
      get :topic_comments, controller_params(id: (1000 + Random.rand(11)))
      assert_response :missing
      assert_equal ' ', @response.body
    end

    def test_comments
      t = Topic.where('posts_count > ?', 1).first || create_test_post(topic_obj, User.first).topic
      get :topic_comments, controller_params(id: t.id)
      result_pattern = []
      t.posts.each do |p|
        result_pattern << comment_pattern(p)
      end
      assert_response 200
      match_json(result_pattern)
    end

    def test_comments_with_pagination
      t = Topic.where('posts_count > ?', 1).first || create_test_post(topic_obj, User.first).topic
      3.times do
        create_test_post(t, User.first)
      end
      get :topic_comments, controller_params(id: t.id, per_page: 1)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      get :topic_comments, controller_params(id: t.id, per_page: 1, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count == 1
    end

    def test_comments_with_pagination_exceeds_limit
      t = Topic.where('posts_count > ?', 1).first || create_test_post(topic_obj, User.first).topic
      get :topic_comments, controller_params(id: t.id, per_page: 101)
      assert_response 400
      match_json([bad_request_error_pattern('per_page', :per_page_invalid_number)])
    end

    def test_comments_with_link_header
      t = create_test_post(topic_obj, User.first).topic
      3.times do
        create_test_post(t, User.first)
      end
      per_page = t.posts.count - 1
      get :topic_comments, controller_params(id: t.id, per_page: per_page)
      assert_response 200
      pattern = []
      t.posts.limit(per_page).each do |f|
        pattern << comment_pattern(f)
      end
      match_json(pattern.ordered!)
      assert JSON.parse(response.body).count == per_page
      assert_equal "<http://#{@request.host}/api/v2/discussions/topics/#{t.id}/comments?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

      get :topic_comments, controller_params(id: t.id, per_page: per_page, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      assert_nil response.headers['Link']
    end
  end
end
