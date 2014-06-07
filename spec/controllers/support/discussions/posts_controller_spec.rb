require File.expand_path("#{File.dirname(__FILE__)}/../../../spec_helper")

describe Support::Discussions::PostsController do
	integrate_views
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
		@account = create_test_account
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
		@user = add_new_user(@account)
	end

	before(:each) do
	    @request.host = @account.full_domain
	    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
	                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
        @request.env['HTTP_REFERER'] = 'support/discussions'
        log_in(@user)
	end

	after(:all) do
		@category.destroy
	end


	it "should create a new post on post 'create'" do
		topic = publish_topic(create_test_topic(@forum))
		post_body = Faker::Lorem.paragraph

		post :create, 
					:post => {
							:body_html =>"<p>#{post_body}</p>"
							},
					:topic_id => topic.id

		new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
		new_post.should_not be_nil
		new_post.topic_id.should eql topic.id
		new_post.user_id.should eql @user.id
		new_post.account_id.should eql @account.id

		response.should redirect_to "support/discussions/topics/#{topic.id}/page/last#post-#{new_post.id}"
	end

	it "should not create a new post on post 'create' when post is invalid" do
		topic = publish_topic(create_test_topic(@forum))

		post :create, 
					:post => {
							:body_html =>""
							},
					:topic_id => topic.id

		@account.posts.find_by_body_html("").should be_nil

		response.should redirect_to "support/discussions/topics/#{topic.id}?page=1"
	end

	it "should not create a new post on post 'create' when topic is not available" do
		topic = create_test_topic(@forum)
		topic_id = topic.id
		topic.destroy
		post_body = Faker::Lorem.paragraph

		post :create, 
					:post => {
							:body_html =>"<p>#{post_body}</p>"
							},
					:topic_id => topic_id

		@account.posts.find_by_body_html("<p>#{post_body}</p>").should be_nil

		response.should redirect_to "support/discussions"
	end

	it "should render edit on get 'edit'" do
		topic = publish_topic(create_test_topic(@forum))
		post = create_test_post(topic)
		post_body = Faker::Lorem.paragraph

		get :edit, :id => post.id,
					:post => {
							:body_html =>"<p>#{post_body}</p>"
							},
					:topic_id => topic.id

		response.should render_template "support/discussions/topics/_edit_post.html.erb"
	end

	it "should update a post on put 'update'" do
		topic = publish_topic(create_test_topic(@forum))
		post = create_test_post(topic)
		post_body = Faker::Lorem.paragraph

		put :update, :id => post.id,
					:post => {
							:body_html =>"<p>#{post_body}</p>"
							},
					:topic_id => topic.id

		post.reload
		post.body_html.should eql "<p>#{post_body}</p>"
		post.topic_id.should eql topic.id

		response.should redirect_to "support/discussions/topics/#{topic.id}?page=1#posts-#{post.id}"
	end

	it "should not update a post on put 'update' when post is invalid" do
		topic = publish_topic(create_test_topic(@forum))
		post = create_test_post(topic)
		put :update, :id => post.id,
					:post => {
							:body_html =>""
							},
					:topic_id => topic.id

		post.reload
		post.body_html.should_not eql ""

		response.should redirect_to "support/discussions/topics/#{topic.id}?page=1#posts-#{post.id}"
	end

	it "should delete a post on delete 'destroy'" do
		topic = publish_topic(create_test_topic(@forum))
		post = create_test_post(topic)
		delete :destroy, :id => post.id,
					:topic_id => topic.id

		@account.posts.find_by_id(post.id).should be_nil

		response.should redirect_to "support/discussions/topics/#{topic.id}?page=1"
	end

	it "should mark a post as answer on 'toggle_answer'" do
		topic = create_test_topic(@forum)
		post = create_test_post(topic)

		put :toggle_answer, :id => post.id, :topic_id => topic.id

		post.reload
		topic.reload
		post.answer.should be_eql true
		topic.stamp_type.should be_eql(Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered])
		topic.answer.should be_eql(post)
		response.should redirect_to "support/discussions/topics/#{topic.id}"
	end

	it "should unmark a post as answer on 'toggle_answer'" do
		topic = create_test_topic(@forum)
		post = mark_as_answer(create_test_post(topic))


		put :toggle_answer, :id => post.id, :topic_id => topic.id

		post.reload
		topic.reload
		post.answer.should be_eql false
		topic.stamp_type.should be_eql(Topic::QUESTIONS_STAMPS_BY_TOKEN[:unanswered])
		topic.answer.should be_nil
		response.should redirect_to "support/discussions/topics/#{topic.id}"
	end

	it "should render best answer on 'best_answer'" do
		post = mark_as_answer(create_test_post(@topic))

	    put :best_answer, :id => post.id, :topic_id => @topic.id

	    response.should render_template "support/discussions/posts/best_answer.html.erb"
	end
end
