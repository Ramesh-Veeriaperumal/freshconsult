require 'spec_helper'

describe Discussions::ModerationController do
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
	end

	before(:each) do
    @request.env['HTTP_REFERER'] = '/categories'
	  login_admin
	end

	after(:all) do
		@category.destroy
	end

	it "should go to the index page" do
	    get 'index'
	    response.should render_template "discussions/moderation/index"
	end

	it "should publish a post on 'approve'" do
		unpublished_post = mark_as_spam(create_test_post(@topic))
		spam_value = unpublished_post.spam

		Resque.inline = true

		put :approve, :id => unpublished_post.id

		Resque.inline = false

		unpublished_post.reload
		unpublished_post.published.should be_truthy
		unpublished_post.spam.should eql spam_value
	end

	it "should unpublish a post when 'put 'mark_as_spam''" do
		published_topic = publish_topic(create_test_topic(@forum))
		published_post = publish_post(create_test_post(published_topic))

		Resque.inline = true

		put :mark_as_spam, :id => published_post.id

		Resque.inline = false

		published_post.reload
		published_post.published.should be_falsey
		published_post.spam.should be_truthy
		if published_post.original_post?
			published_topic.reload
			published_topic.published.should be_falsey
		end
	end

	it "should trash multiple posts when 'delete 'empty_folder''" do
		unpublished_spam = []
		unpublished_spam << mark_as_spam(create_test_topic(@forum).posts.first)
		5.times do |n|
			unpublished_spam << mark_as_spam(create_test_post(@topic))
		end

		Resque.inline = true

		delete :empty_folder

		Resque.inline = false

		unpublished_spam.each do |post|
			@account.posts.find_by_id(post.id).should be_nil
		end

		response.should redirect_to discussions_path
	end

	it "should mark as spam multiple posts when 'put 'spam_multiple''" do
		topic_1 = publish_topic(create_test_topic(@forum))
		topic_2 = publish_topic(create_test_topic(@forum))
		published_topics = [topic_1, topic_2]
		publish_post(create_test_post(topic_1))
		publish_post(create_test_post(topic_2))

		put :spam_multiple, :ids => [topic_1.id, topic_2.id]

		published_topics.each do |topic|
			topic.reload
			topic.published.should be_falsey
			topic.posts.first.published.should be_falsey
			topic.posts.first.spam.should be_truthy
		end
	end

	it "should spam all posts of a user when 'put 'ban_user'' " do
		user_posts = []
		user_posts << publish_topic(create_test_topic(@forum)).posts.first
		user_posts << publish_post(create_test_post(@topic))

		#approval posts
		user_posts << create_test_topic(@forum).posts.first
		user_posts << create_test_post(@topic)

		spam_post = mark_as_spam(create_test_post(@topic))

		put :ban, :id => spam_post.id

		user_posts.each do |post|
			post.reload
			post.published.should be_false
			post.spam.should be_true
		end

	end

	it "should redirect to unpublished controller when account has dynamo feature" do
		@account.features.spam_dynamo.create
		@account.reload

		get 'index'
		response.should redirect_to "/discussions/unpublished"

		@account.features.spam_dynamo.destroy
	end

end