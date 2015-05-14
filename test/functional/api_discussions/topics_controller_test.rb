require_relative '../../test_helper'

module ApiDiscussions
  class TopicsControllerTest < ActionController::TestCase

    def forum_obj
      Forum.first
    end

    def first_topic
      Topic.first
    end

    def last_topic
      Topic.last
    end

    def wrap_cname params
      {:topic => params}
    end
     
    def test_create
      post :create, construct_params({}, {:forum_id=> forum_obj.id, 
        :title => "test title", :message_html => "test content"})
      match_json(topic_pattern(last_topic))
      match_json(topic_pattern({:forum_id => forum_obj.id, :title => "test title", :posts_count => 1}, last_topic))
      assert_response :created
    end

    def test_create_with_email
      user = add_new_user(@account)
      post :create, construct_params({}, {:forum_id=> forum_obj.id,
       :title => "test title", :message_html => "test content", :email => user.email})
      match_json(topic_pattern(last_topic))
      match_json(topic_pattern({:forum_id => forum_obj.id, :title => "test title", :posts_count => 1, :user_id => user.id}, last_topic))
      assert_response :created
    end

    def test_create_with_user_id
      user = add_new_user(@account)
      post :create, construct_params({}, {:forum_id=> forum_obj.id,
       :title => "test title", :message_html => "test content", :user_id => user.id})
      match_json(topic_pattern(last_topic))
      match_json(topic_pattern({:forum_id => forum_obj.id, :title => "test title", :user_id => user.id, :posts_count => 1}, last_topic))
      assert_response :created
    end

    def test_create_with_created_at
      created_at = 2.days.ago.to_s
      post :create, construct_params({}, {:forum_id=> forum_obj.id,
       :title => "test title", :message_html => "test content", :created_at => created_at})
      match_json(topic_pattern(last_topic))
      match_json(topic_pattern({:forum_id => forum_obj.id, :title => "test title", :posts_count => 1,
       :created_at => created_at, :ignore_created_at => false}, last_topic))
      assert_response :created
    end

    def test_create_with_stamp_type
      forum = forum_obj
      forum.update_column(:forum_type, 2)
      post :create, construct_params({}, {:forum_id=> forum.id,
       :title => "test title", :message_html => "test content", :stamp_type => 3})
      match_json(topic_pattern({}, last_topic))
      match_json(topic_pattern({:forum_id => forum.id, :title => "test title", :posts_count => 1,
       :stamp_type => 3}, last_topic))
      assert_response :created
    end

    def test_create_without_title
      post :create, construct_params({}, {:forum_id=> forum_obj.id,
       :message_html => "test content"})
      match_json([bad_request_error_pattern("title", "can't be blank")])
      assert_response :bad_request
    end

    def test_create_without_message
      post :create, construct_params({}, {:forum_id=> forum_obj.id,
       :title => "test title"})
      match_json([bad_request_error_pattern("message_html", "can't be blank")])
      assert_response :bad_request
    end

    def test_create_without_forum_id
      post :create, construct_params({}, { :title => "test title",
       :message_html => "test content"})
      match_json([bad_request_error_pattern("forum_id", "is not a number")])
      assert_response :bad_request
    end

    def test_create_invalid_user_id
      post :create, construct_params({}, {:forum_id => forum_obj.id,
       :title => "test title", :message_html => "test content", :user_id => (1000 + Random.rand(11))})
      match_json([bad_request_error_pattern("user", "can't be blank")])
      assert_response :bad_request
    end

    def test_create_invalid_forum_id
      post :create, construct_params({}, { :title => "test title",
       :message_html => "test content", :forum_id => (1000 + Random.rand(11))})
      match_json([bad_request_error_pattern("forum", "can't be blank")])
      assert_response :bad_request
    end

    def test_create_invalid_created_at
      post :create, construct_params({}, {:forum_id => forum_obj.id,
       :title => "test title", :message_html => "test content", :created_at => "2018-78-90T89:88:90"})
      match_json([bad_request_error_pattern("created_at", "is not a date")])
      assert_response :bad_request
    end

    def test_create_invalid_updated_at
      post :create, construct_params({}, {:forum_id => forum_obj.id,
       :title => "test title", :message_html => "test content", :updated_at => "2018-78-90T89:88:90"})
      match_json([bad_request_error_pattern("updated_at", "is not a date")])
      assert_response :bad_request
    end

    def test_create_validate_numericality
      post :create, construct_params({}, {:forum_id => "junk",
       :title => "test title", :message_html => "test content", :stamp_type => "hj", :user_id => "junk"})
      match_json([bad_request_error_pattern("forum_id", "is not a number"),
        bad_request_error_pattern("user_id", "is not a number"),
        bad_request_error_pattern("stamp_type", "is not a number")])
      assert_response :bad_request
    end

    def test_create_validate_inclusion
      post :create, construct_params({}, {:forum_id => forum_obj.id,
       :title => "test title", :message_html => "test content",  :sticky => "junk", :locked => "junk2"})
      match_json([bad_request_error_pattern("locked", "is not included in the list", {:list => "0,false,1,true"}),
       bad_request_error_pattern("sticky", "is not included in the list", {:list => "0,false,1,true"})])
      assert_response :bad_request
    end

    def test_before_filters_show
      @controller.expects(:verify_authenticity_token).never
      @controller.expects(:check_privilege).never
      @controller.expects(:portal_check).once
      get :show, construct_params(:id => 1)
    end

    def test_show
      topic = create_test_topic(forum_obj)
      get :show, construct_params(:id => topic.id)
      result_pattern = topic_pattern(topic)
      result_pattern[:posts] = Array
      match_json(result_pattern)
      assert_response :success
    end

    def test_show_invalid_id
      get :show, construct_params(:id => (1000 + Random.rand(11)))
      assert_response :not_found
      assert_equal " ", @response.body   
    end

    def test_show_with_posts
      t = Topic.where("posts_count > ?", 1).first || create_test_post(first_topic, User.first).topic
      get :show, construct_params(:id => t.id)
      result_pattern = topic_pattern(t)
      result_pattern[:posts] = []
      t.posts.each do |p|
        result_pattern[:posts] << post_pattern(p)
      end
      assert_response :success
      match_json(result_pattern)
    end

    def test_posts_invalid_id
      get :posts, construct_params(:id => (1000 + Random.rand(11))) 
      assert_response :not_found
      assert_equal " ", @response.body   
    end

    def test_posts
      t = Topic.where("posts_count > ?", 1).first || create_test_post(Topic.first, User.first).topic
      get :posts, construct_params(:id => t.id)
      result_pattern = []
      t.posts.each do |p|
        result_pattern << post_pattern(p)
      end
      assert_response :success
      match_json(result_pattern)
    end

    def test_create_without_view_admin_privilege
      user = add_new_user(@account)
      controller.class.any_instance.stubs(:privilege?).with(:all).returns(true).once
      controller.class.any_instance.stubs(:privilege?).with(:edit_topic).returns(true).once
      controller.class.any_instance.stubs(:privilege?).with(:view_admin).returns(false).once
      controller.class.any_instance.stubs(:privilege?).with(:manage_forums).returns(true).once
      post :create, construct_params({}, {:forum_id=> forum_obj.id,
       :title => "test title", :message_html => "test content", :email => user.email})
      assert_response :bad_request
      match_json([bad_request_error_pattern("email", "invalid_field")])
    end

     def test_create_without_edit_topic_privilege
      user = add_new_user(@account)
      controller.class.any_instance.stubs(:privilege?).with(:all).returns(true).once
      controller.class.any_instance.stubs(:privilege?).with(:edit_topic).returns(false).once
      controller.class.any_instance.stubs(:privilege?).with(:view_admin).returns(true).once
      controller.class.any_instance.stubs(:privilege?).with(:manage_forums).returns(true).once
      post :create, construct_params({}, {:forum_id=> forum_obj.id,
       :title => "test title", :message_html => "test content", :sticky => 1})
      assert_response :bad_request
      match_json([bad_request_error_pattern("sticky", "invalid_field")])
    end

    def test_update_without_edit_topic_privilege
      topic = first_topic
      controller.class.any_instance.stubs(:privilege?).with(:all).returns(true).once
      controller.class.any_instance.stubs(:privilege?).with(:edit_topic).returns(false).once
      controller.class.any_instance.stubs(:privilege?).with(:view_admin).never
      controller.class.any_instance.stubs(:privilege?).with(:manage_forums).returns(true).once
      put :update, construct_params({:id => topic}, {:sticky => !topic.sticky})
      assert_response :bad_request
      match_json([bad_request_error_pattern("sticky", "invalid_field")])  
    end

    def test_update_with_email
      topic = first_topic
      put :update, construct_params({:id => topic}, {:email => "test@test.com"})
      assert_response :bad_request
      match_json([bad_request_error_pattern("email", "invalid_field")])  
    end

    def test_update_with_no_params
      put :update, construct_params({:id => first_topic.id}, {})
      assert_response :bad_request
      match_json(request_error_pattern("missing_params"))  
    end

    def test_update
      topic = first_topic
      params = {:title => "New", :message_html => "New msg", 
       :stamp_type => Topic::FORUM_TO_STAMP_TYPE[Forum.last.forum_type].last,
       :sticky => !topic.sticky, :locked => !topic.locked, :forum_id => Forum.last.id}
      put :update, construct_params({:id => first_topic.id}, params)
      match_json(topic_pattern(first_topic))
      match_json(topic_pattern(params, first_topic))
      assert_response :success
    end

    def test_update_with_invalid_stamp_type
      forum = first_topic.forum
      forum.update_column(:forum_type, 2)
      put :update, construct_params({:id => first_topic.id}, {:stamp_type => 78})
      match_json([bad_request_error_pattern("stamp_type", "allowed values are 1,4,5,2,3,nil")])
      assert_response :bad_request
    end

    def test_update_without_title
      put :update, construct_params({:id => first_topic.id}, {:title => ""})
      match_json([bad_request_error_pattern("title", "can't be blank")])
      assert_response :bad_request
    end

    def test_update_without_message
      put :update, construct_params({:id => first_topic.id}, {:forum_id=> forum_obj.id, 
        :message_html => ""})
      match_json([bad_request_error_pattern("message_html", "can't be blank")])
      assert_response :bad_request
    end

    def test_update_invalid_forum_id
      put :update, construct_params({:id => first_topic.id}, {:forum_id => (1000 + Random.rand(11))})
      match_json([bad_request_error_pattern("forum", "can't be blank")])
      assert_response :bad_request
    end

  end
end