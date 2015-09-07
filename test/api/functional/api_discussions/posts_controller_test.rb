require_relative '../../test_helper'

module ApiDiscussions
  class PostsControllerTest < ActionController::TestCase
    include Helpers::DiscussionsHelper

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
      put :update, construct_params({ id: post.id }, body_html: 'test reply 2', answer: true)
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
      match_json([bad_request_error_pattern('answer', 'data_type_mismatch', data_type: 'Boolean')])
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
      post :create, construct_params({ id: topic_obj.id }, {})
      assert_response :bad_request
      match_json [bad_request_error_pattern('body_html', 'missing_field')]
    end

    def test_create_mandatory_params
      topic = topic_obj
      post :create, construct_params({ id: topic.id }, body_html: 'test')
      assert_response :created
      match_json(post_pattern(Post.last))
      match_json(post_pattern({ body_html: 'test', topic_id: topic.id,
                                user_id: @agent.id }, Post.last))
    end

    def test_create_returns_location_header
      topic = topic_obj
      post :create, construct_params({ id: topic.id }, body_html: 'test')
      assert_response :created
      match_json(post_pattern(Post.last))
      match_json(post_pattern({ body_html: 'test', topic_id: topic.id,
                                user_id: @agent.id }, Post.last))
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/discussions/posts/#{result['id']}", response.headers['Location']
    end

    def test_create_invalid_model
      post :create, construct_params({ id: 34_234_234 }, body_html: 'test')
      assert_response :not_found
    end

    def test_create_invalid_user_field
      post :create, construct_params({ id: topic_obj.id }, :body_html => 'test',
                                                           'user_id' => 999)
      assert_response :bad_request
      match_json([bad_request_error_pattern('user_id', 'invalid_field')])
    end

    def test_posts_invalid_id
      get :topic_posts, construct_params(id: (1000 + Random.rand(11)))
      assert_response :not_found
      assert_equal ' ', @response.body
    end

    def test_posts
      t = Topic.where('posts_count > ?', 1).first || create_test_post(Topic.first, User.first).topic
      get :topic_posts, construct_params(id: t.id)
      result_pattern = []
      t.posts.each do |p|
        result_pattern << post_pattern(p)
      end
      assert_response :success
      match_json(result_pattern)
    end

    def test_posts_with_pagination
      t = Topic.where('posts_count > ?', 1).first || create_test_post(topic_obj, User.first).topic
      3.times do
        create_test_post(t, User.first)
      end
      get :topic_posts, construct_params(id: t.id, per_page: 1)
      assert_response :success
      assert JSON.parse(response.body).count == 1
      get :topic_posts, construct_params(id: t.id, per_page: 1, page: 2)
      assert_response :success
      assert JSON.parse(response.body).count == 1
    end

    def test_posts_with_pagination_exceeds_limit
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:per_page).returns(2)
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:max_per_page).returns(3)
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:page).returns(1)
      t = topic_obj
      4.times do
        create_test_post(t, User.first)
      end
      get :topic_posts, construct_params(id: t.id, per_page: 4)
      assert_response :success
      assert JSON.parse(response.body).count == 3
      ApiConstants::DEFAULT_PAGINATE_OPTIONS.unstub(:[])
    end

    def test_posts_with_link_header
      t = create_test_post(topic_obj, User.first).topic
      3.times do
        create_test_post(t, User.first)
      end
      per_page = t.posts.count - 1
      get :topic_posts, construct_params(id: t.id, per_page: per_page)
      assert_response :success
      assert JSON.parse(response.body).count == per_page
      assert_equal "<http://#{@request.host}/api/v2/discussions/topics/#{t.id}/posts?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

      get :topic_posts, construct_params(id: t.id, per_page: per_page, page: 2)
      assert_response :success
      assert JSON.parse(response.body).count == 1
      assert_nil response.headers['Link']
    end
  end
end
