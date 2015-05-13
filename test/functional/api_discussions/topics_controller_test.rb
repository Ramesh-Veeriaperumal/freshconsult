require_relative '../../test_helper'

module ApiDiscussions
  class TopicsControllerTest < ActionController::TestCase
     
    def test_create
      post :create, :version => "v2", :format => :json, :topic => {:forum_id=> Forum.first.id, :title => "test title", :message_html => "test content"} 
      response.body.must_match_json_expression(topic_pattern(Topic.last))
      response.body.must_match_json_expression(topic_pattern({:forum_id => Forum.first.id, :title => "test title", :posts_count => 1}, Topic.last))
      assert_response :created
    end

    def test_create_with_email
      user = add_new_user(@account)
      post :create, :version => "v2", :format => :json, :topic => {:forum_id=> Forum.first.id, :title => "test title", :message_html => "test content", :email => user.email} 
      response.body.must_match_json_expression(topic_pattern(Topic.last))
      response.body.must_match_json_expression(topic_pattern({:forum_id => Forum.first.id, :title => "test title", :posts_count => 1, :user_id => user.id}, Topic.last))
      assert_response :created
    end

    def test_create_with_user_id
      user = add_new_user(@account)
      post :create, :version => "v2", :format => :json, :topic => {:forum_id=> Forum.first.id, :title => "test title", :message_html => "test content", :user_id => user.id} 
      response.body.must_match_json_expression(topic_pattern(Topic.last))
      response.body.must_match_json_expression(topic_pattern({:forum_id => Forum.first.id, :title => "test title", :user_id => user.id, :posts_count => 1}, Topic.last))
      assert_response :created
    end

    def test_create_with_created_at
      created_at = 2.days.ago.to_s
      post :create, :version => "v2", :format => :json, :topic => {:forum_id=> Forum.first.id, :title => "test title", :message_html => "test content", :created_at => created_at} 
      response.body.must_match_json_expression(topic_pattern(Topic.last))
      response.body.must_match_json_expression(topic_pattern({:forum_id => Forum.first.id, :title => "test title", :posts_count => 1, :created_at => created_at, :ignore_created_at => false}, Topic.last))
      assert_response :created
    end

    def test_create_without_title
      post :create, :version => "v2", :format => :json, :topic => {:forum_id=> Forum.first.id, :message_html => "test content"} 
      response.body.must_match_json_expression([bad_request_error_pattern("title", "can't be blank")])
      assert_response :bad_request
    end

    def test_create_without_message
      post :create, :version => "v2", :format => :json, :topic => {:forum_id=> Forum.first.id, :title => "test title"} 
      response.body.must_match_json_expression([bad_request_error_pattern("message_html", "can't be blank")])
      assert_response :bad_request
    end

    def test_create_without_forum_id
      post :create, :version => "v2", :format => :json, :topic => { :title => "test title", :message_html => "test content"} 
      response.body.must_match_json_expression([bad_request_error_pattern("forum_id", "can't be blank")])
      assert_response :bad_request
    end

    def test_create_invalid_user_id
      post :create, :version => "v2", :format => :json, :topic => {:forum_id => Forum.first.id, :title => "test title", :message_html => "test content", :user_id => (1000 + Random.rand(11))} 
      response.body.must_match_json_expression([bad_request_error_pattern("user", "can't be blank")])
      assert_response :bad_request
    end

    def test_create_invalid_forum_id
      post :create, :version => "v2", :format => :json, :topic => { :title => "test title", :message_html => "test content", :forum_id => (1000 + Random.rand(11))} 
      response.body.must_match_json_expression([bad_request_error_pattern("forum", "can't be blank")])
      assert_response :bad_request
    end

    def test_create_invalid_created_at
      post :create, :version => "v2", :format => :json, :topic => {:forum_id => Forum.first.id, :title => "test title", :message_html => "test content", :created_at => "2018-78-90T89:88:90"} 
      response.body.must_match_json_expression([bad_request_error_pattern("created_at", "is not a date")])
      assert_response :bad_request
    end

    def test_create_invalid_updated_at
      post :create, :version => "v2", :format => :json, :topic => {:forum_id => Forum.first.id, :title => "test title", :message_html => "test content", :updated_at => "2018-78-90T89:88:90"} 
      response.body.must_match_json_expression([bad_request_error_pattern("updated_at", "is not a date")])
      assert_response :bad_request
    end

    def test_create_validate_numericality
      post :create, :version => "v2", :format => :json, :topic => {:forum_id => "junk", :title => "test title", :message_html => "test content", :stamp_type => "hj", :user_id => "junk"} 
      response.body.must_match_json_expression([bad_request_error_pattern("forum_id", "is not a number"),
        bad_request_error_pattern("user_id", "is not a number"),
        bad_request_error_pattern("stamp_type", "is not a number")])
      assert_response :bad_request
    end

    def test_create_validate_inclusion
      post :create, :version => "v2", :format => :json, :topic => {:forum_id => Forum.first.id, :title => "test title", :message_html => "test content",  :sticky => "junk", :locked => "junk2"} 
      response.body.must_match_json_expression([bad_request_error_pattern("locked", "is not included in the list", {:list => ""}), bad_request_error_pattern("sticky", "is not included in the list", {:list => ""})])
      assert_response :bad_request
    end

    def test_before_filters_show
      @controller.expects(:verify_authenticity_token).never
      @controller.expects(:check_privilege).never
      @controller.expects(:portal_check).once
      get :show, :id => 1, :version => "v2", :format => :json  
    end

    def show
      topic = create_test_topic
      get :show, :version => "v2", :format => :json, :id => topic.id
      result_pattern = topic_pattern(topic)
      result_pattern[:posts] = Array
      response.body.must_match_json_expression(result_pattern)
      assert_response :success
    end

    def show_invalid_id
      get :show, :version => "v2", :format => :json, :id => (1000 + Random.rand(11))
      assert_response :not_found
      assert_equal " ", @response.body   
    end

    def test_show_with_posts
      t = Topic.where("posts_count > ?", 1).first || create_test_post(Topic.first, User.first).topic
      get :show, :id => t.id, :version => "v2", :format => :json
      result_pattern = topic_pattern(t)
      result_pattern[:posts] = []
      t.posts.each do |p|
        result_pattern[:posts] << post_pattern(p)
      end
      response.body.must_match_json_expression(result_pattern)
    end

    def test_create_without_view_admin_privilege
      user = add_new_user(@account)
      controller.class.any_instance.stubs(:privilege?).with(:all).returns(true)
      controller.class.any_instance.stubs(:privilege?).with(:edit_topic).returns(true)
      controller.class.any_instance.stubs(:privilege?).with(:view_admin).returns(false)
      controller.class.any_instance.stubs(:privilege?).with(:manage_forums).returns(true)
      post :create, :version => "v2", :format => :json, :topic => {:forum_id=> Forum.first.id, :title => "test title", :message_html => "test content", :email => user.email} 
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("email", "invalid_field")])
    end

     def test_create_without_edit_topic_privilege
      user = add_new_user(@account)
      controller.class.any_instance.stubs(:privilege?).with(:all).returns(true)
      controller.class.any_instance.stubs(:privilege?).with(:edit_topic).returns(false)
      controller.class.any_instance.stubs(:privilege?).with(:view_admin).returns(true)
      controller.class.any_instance.stubs(:privilege?).with(:manage_forums).returns(true)
      post :create, :version => "v2", :format => :json, :topic => {:forum_id=> Forum.first.id, :title => "test title", :message_html => "test content", :sticky => 1} 
      assert_response :bad_request
      response.body.must_match_json_expression([bad_request_error_pattern("sticky", "invalid_field")])
    end
  end
end