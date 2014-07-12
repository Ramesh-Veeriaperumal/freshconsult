require 'spec_helper'

describe Support::Discussions::PostsController do
	integrate_views
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

			response.should redirect_to "support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
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
			post.published.should eql false

			response.should redirect_to "support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
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
			post.published.should eql false

			response.should redirect_to "support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
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

			response.should redirect_to "support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
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

			response.should redirect_to "support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
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

			response.should redirect_to "support/discussions/topics/#{topic.id}/page/last#post-#{post.id}"
		end
	end
end
