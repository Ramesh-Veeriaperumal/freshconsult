require 'spec_helper'

describe Support::Discussions::PostsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

	before(:all) do
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
		@user = add_new_user(@account)
	end

	before(:each) do
    @request.env['HTTP_REFERER'] = 'support/discussions'
    log_in(@user)
    @account.features.hide_portal_forums.destroy#TODO-RAILS3 fix
	end

	after(:all) do
		@category.destroy
	end


	it "should create a new post on post 'create'" do
		topic = publish_topic(create_test_topic(@forum))
		post_body = Faker::Lorem.paragraph
		old_follower_count = Monitorship.count

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
		Monitorship.count.should eql old_follower_count + 1
		Monitorship.last.portal_id.should_not be_nil

		response.should redirect_to "/support/discussions/topics/#{topic.id}/page/last#post-#{new_post.id}"
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
		response.should render_template "support/discussions/topics/_edit_post"
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

		post.reload
		post.body_html.should eql "<p>#{post_body}</p>"
		post.topic_id.should eql topic.id

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

	it "should mark a post as answer on 'toggle_answer' if author or agent" do
		topic = create_test_topic(@forum, @user)
		post = create_test_post(topic, @user)

		put :toggle_answer, :id => post.id, :topic_id => topic.id

		post.reload
		topic.reload
		post.answer.should be_eql true
		topic.stamp_type.should be_eql(Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered])
		topic.answer.should be_eql(post)
		response.should redirect_to "/support/discussions/topics/#{topic.id}"
	end

	it "should unmark a post as answer on 'toggle_answer' if author or agent" do
		topic = create_test_topic(@forum, @user)
		post = mark_as_answer(create_test_post(topic, @user))


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
			log_in(@second_user)
		end

		after(:all) do
			log_in(@user)
		end

		it "should redirect to login page post on edit on get 'edit' if not author or agent" do
			post_body = Faker::Lorem.paragraph

			get :edit, :id => @new_post.id,
						:post => {
								:body_html =>"<p>#{post_body}</p>"
								},
						:topic_id => @new_topic.id
			response.should redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
		end

		it "should redirect to login page on put 'update' if not author or agent" do
			post_body = Faker::Lorem.paragraph

			put :update, :id => @new_post.id,
	      :post => {
	      :body_html =>"<p>#{post_body}</p>"
	    },
	      :topic_id => @new_topic.id

			response.should redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
		end

		it "should redirect to login page on marking a post as answer on 'toggle_answer' by a non-agent or author" do
			put :toggle_answer, :id => @new_post.id, :topic_id => @new_topic.id

			response.should redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
		end
	end


	describe "should check for spam" do

		after(:each) do
			@account.features.moderate_all_posts.destroy
			@account.features.moderate_posts_with_links.destroy
			@account.reload
		end

		it "with 'do not moderate feature' and should mark as published" do
			topic = publish_topic(create_test_topic(@forum))
			post_body = Faker::Lorem.paragraph

			Resque.inline = true

			post :create, 
        :post => {
        :body_html =>"<p>#{post_body}</p>"
      },
        :topic_id => topic.id

			Resque.inline = false

			post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
			post.published.should eql true
			response.should redirect_to "/support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
		end

		it "with 'moderate all posts' feature and should mark as unpublished" do
			topic = publish_topic(create_test_topic(@forum))
			post_body = Faker::Lorem.paragraph

			@account.features.moderate_all_posts.create
			Resque.inline = true

			post :create, 
        :post => {
        :body_html =>"<p>#{post_body}</p>"
      },
        :topic_id => topic.id

			Resque.inline = false

			post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
			post.published.should eql(false)
			response.should redirect_to "/support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
		end

		it "with 'moderate posts with link' feature and with email" do
			topic = publish_topic(create_test_topic(@forum))
			post_body = Faker::Lorem.paragraph
			email = Faker::Internet.email

			@account.features.moderate_posts_with_links.create
			Resque.inline = true

			post :create, 
        :post => {
        :body_html =>"<p>#{post_body}#{email}</p>"
      },
        :topic_id => topic.id

			Resque.inline = false

			post = @account.posts.find_by_body_html("<p>#{post_body}#{email}</p>")
			post.published.should eql(false)
			response.should redirect_to "/support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
		end

		it "with 'moderate posts with link' feature and with phone number" do
			topic = publish_topic(create_test_topic(@forum))
			post_body = Faker::Lorem.paragraph
			phone = ForumHelper::PHONE_NUMBERS.sample

			@account.features.moderate_posts_with_links.create
			Resque.inline = true

			post :create, 
        :post => {
        :body_html =>"<p>#{post_body} #{phone}</p>"
      },
        :topic_id => topic.id

			Resque.inline = false

			post = @account.posts.find_by_body_html("<p>#{post_body} #{phone}</p>")
			post.published.should eql false
			response.should redirect_to "/support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
		end

		it "with 'moderate posts with link' feature and with link" do
			topic = publish_topic(create_test_topic(@forum))
			post_body = Faker::Lorem.paragraph
			link = Faker::Internet.url

			@account.features.moderate_posts_with_links.create
			Resque.inline = true

			post :create, 
        :post => {
        :body_html =>"<p>#{post_body} #{link}</p>"
      },
        :topic_id => topic.id

			Resque.inline = false

			post = @account.posts.find_by_body_html("<p>#{post_body} #{link}</p>")
			post.published.should eql false
			response.should redirect_to "/support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
		end

		it "with 'moderate posts with link' feature and with whitelisted link" do
			topic = publish_topic(create_test_topic(@forum))
			post_body = Faker::Lorem.paragraph
			whitelisted_link = "https://www.youtube.com/watch?v=lbJO8MBCyp4"

			@account.features.moderate_posts_with_links.create
			Resque.inline = true

			post :create, 
        :post => {
        :body_html =>"<p>#{post_body} #{whitelisted_link}</p>"
      },
        :topic_id => topic.id

			Resque.inline = false

			post = @account.posts.find_by_body_html("<p>#{post_body} #{whitelisted_link}</p>")
			post.published.should eql true
			response.should redirect_to "/support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
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
end
