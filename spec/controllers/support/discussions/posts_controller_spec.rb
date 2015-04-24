require 'spec_helper'

describe Support::Discussions::PostsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

	before(:all) do
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
		@user = add_new_user(@account)
		@account.features.spam_dynamo.destroy
	end

	before(:each) do
    @request.env['HTTP_REFERER'] = 'support/discussions'
    log_in(@user)
	end

	after(:all) do
		@category.destroy
	end

	it "should not create a new post on post 'create' when post is invalid" do
		topic = publish_topic(create_test_topic(@forum))

		post :create, 
      :post => {
      :body_html => ""
    },
      :topic_id => topic.id

		@account.posts.find_by_body_html("").should be_nil

		response.should redirect_to "/support/discussions/topics/#{topic.id}?page=1"
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

		response.should redirect_to "/support/discussions"
	end

	it "should render edit on get 'edit' if author or agent" do
		topic = publish_topic(create_test_topic(@forum))
		post = create_test_post(topic, @user)
		post_body = Faker::Lorem.paragraph

		get :edit, :id => post.id,
					:post => {
							:body_html =>"<p>#{post_body}</p>"
							},
					:topic_id => topic.id
		response.should be_success
	end

	it "should update a post on put 'update' if author or agent" do
		topic = publish_topic(create_test_topic(@forum))
		post = create_test_post(topic, @user)
		post_body = Faker::Lorem.paragraph

		put :update, :id => post.id,
					:post => {
							:body_html =>"<p>#{post_body}</p>"
							},
					:topic_id => topic.id

		response.should redirect_to "/support/discussions/topics/#{topic.id}?page=1#posts-#{post.id}"
	end

	it "should not update a post on put 'update' when post is invalid" do
		topic = publish_topic(create_test_topic(@forum))
		post = create_test_post(topic, @user)
		put :update, :id => post.id,
      :post => {
      :body_html =>""
    },
      :topic_id => topic.id

		post.reload
		post.body_html.should_not eql ""

		response.should redirect_to "/support/discussions/topics/#{topic.id}?page=1#posts-#{post.id}"
	end

	it "should delete a post on delete 'destroy'" do
		topic = publish_topic(create_test_topic(@forum))
		post = create_test_post(topic, @user)
		delete :destroy, :id => post.id,
      :topic_id => topic.id

		@account.posts.find_by_id(post.id).should be_nil

		response.should redirect_to "/support/discussions/topics/#{topic.id}?page=1"
	end

	it "should mark a post as answer on 'toggle_answer'" do
		topic = create_test_topic(@forum, @user)
		post = create_test_post(topic)

		# Error Cause: Current user is being reset
		put :toggle_answer, :id => post.id, :topic_id => topic.id

		post.reload
		topic.reload
		post.answer.should be_eql true
		topic.stamp_type.should be_eql(Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered])
		topic.answer.should be_eql(post)
		response.should redirect_to "/support/discussions/topics/#{topic.id}"
	end

	it "should unmark a post as answer on 'toggle_answer'" do
		topic = create_test_topic(@forum, @user)
		post = mark_as_answer(create_test_post(topic))

		# Error Cause: Current user is being reset
		put :toggle_answer, :id => post.id, :topic_id => topic.id

		post.reload
		topic.reload
		post.answer.should be_eql false
		topic.stamp_type.should be_eql(Topic::QUESTIONS_STAMPS_BY_TOKEN[:unanswered])
		topic.answer.should be_nil
		response.should redirect_to "/support/discussions/topics/#{topic.id}"
	end

	it "should render best answer on 'best_answer'" do
		post = mark_as_answer(create_test_post(@topic))

    put :best_answer, :id => post.id, :topic_id => @topic.id

    response.should render_template "support/discussions/posts/best_answer"
	end

	describe "should redirect to login page when a non-author or non-agent tries to make changes to a post" do

		before(:all) do
			@first_user = add_new_user(@account)
			@second_user = add_new_user(@account)
			@new_topic = publish_topic(create_test_topic(@forum))
			@new_post = create_test_post(@new_topic, @first_user)
		end

    before(:each) do
      log_in(@second_user)
    end

		after(:all) do
			log_in(@user)
		end

		it "should return 200 status on edit if not author or agent" do
			post_body = Faker::Lorem.paragraph

			get :edit, :id => @new_post.id,
						:post => {
								:body_html =>"<p>#{post_body}</p>"
								},
						:topic_id => @new_topic.id
			response.code.should eq("200")
		end

		it "should redirect to topic page on put 'update' if not author or agent" do
			post_body = Faker::Lorem.paragraph
			put :update, :id => @new_post.id,
	      :post => {
	      :body_html =>"<p>#{post_body}</p>"
	    },
	      :topic_id => @new_topic.id
			response.should redirect_to support_discussions_topic_path(:id => @new_topic.id, :anchor => @new_post.dom_id, :page => '1')
		end

		it "should redirect to login page on marking a post as answer on 'toggle_answer' by a non-agent or author" do
			put :toggle_answer, :id => @new_post.id, :topic_id => @new_topic.id

			response.should redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
		end
	end
	
	it "should redirect to support home if portal forums is disabled" do
		topic = publish_topic(create_test_topic(@forum))
		@account.features.hide_portal_forums.create

		post :create, 
      :post => {
      :body_html =>"<p>#{Faker::Lorem.paragraph}</p>"
    },
      :topic_id => create_test_post(topic).id
		response.should redirect_to "/support/home"

		post = create_test_post(topic)

		get :show, :topic_id => topic.id, :id => post.id
		response.should redirect_to "/support/home"

		get :edit, :topic_id => topic.id, :id => post.id
		response.should redirect_to "/support/home"

		get :best_answer, :topic_id => topic.id, :id => post.id
		response.should redirect_to "/support/home"

		put :update, :topic_id => topic.id, :id => post.id
		response.should redirect_to "/support/home"

		put :toggle_answer, :topic_id => topic.id, :id => post.id
		response.should redirect_to "/support/home"
    
		delete :destroy, :topic_id => topic.id, :id => post.id
		response.should redirect_to "/support/home"			
      
		@account.features.hide_portal_forums.destroy
	end
	
	describe "it should create a post if the user is agent" do

		before(:each) do
			login_admin
			@topic = publish_topic(create_test_topic(@forum))
		end

		it "should create a post with attachments on post 'create'" do
			post_body = Faker::Lorem.paragraph
			old_follower_count = Monitorship.count
		
			post :create,
				:topic_id => @topic.id,
				:post => { :body_html =>"<p>#{post_body}</p>",
					:attachments => [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')}]}

			new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
			new_post.should be_instance_of(Post)
			new_post.user_id.should be_eql @agent.id
			new_post.topic_id.should be_eql @topic.id
			new_post.account_id.should be_eql @account.id
			Monitorship.count.should eql old_follower_count + 1
			Monitorship.last.portal_id.should_not be_nil
			
			response.should redirect_to "/support/discussions/topics/#{@topic.id}/page/last#post-#{new_post.id}"
		end

		it "should not create a post on post 'create' when the post is invalid" do
			
			post :create, 
						:post => {
								:body_html =>""
								},
						:topic_id => @topic.id

			@account.posts.find_by_body_html('').should be_nil

			response.should redirect_to "/support/discussions/topics/#{@topic.id}?page=1"
		end
		
	end

	it "should not create a new post on post 'create' when topic is locked" do
		topic = lock_topic(create_test_topic(@forum))
		topic.published = false
		topic.save
		post_body = Faker::Lorem.paragraph

		post :create, 
					:post => {
							:body_html =>"<p>#{post_body}</p>"
							},
					:topic_id => topic.id

		@account.posts.find_by_body_html("<p>#{post_body}</p>").should be_nil
		response.should redirect_to "/support/discussions/topics/#{topic.id}?page=1"
	end

end
