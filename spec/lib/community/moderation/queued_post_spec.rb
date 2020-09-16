require 'spec_helper'

describe Community::Moderation::QueuedPost do
	
	before(:all) do
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
		@user = add_new_user(@account)
		@user2 = add_new_user(@account, { :name => 'viagra-test-123'})
	end

	before(:each) do
		 @account.make_current
		 @account.reload
	end

	after(:all) do
		@account.features.moderate_all_posts.destroy
		@account.features.moderate_posts_with_links.destroy
		delete_dynamo_posts("ForumSpam")
		delete_dynamo_posts("ForumUnpublished")
		@category.destroy
	end

	it "should create a dynamo approval topic" do
		@account.features.moderate_all_posts.create
		sqs_params = sqs_topic_params

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		approval_topic = ForumUnpublished.find(:account_id => @account.id, :timestamp => sqs_params['timestamp'])
		approval_topic.should_not be_nil
		approval_topic.body_html.should eql sqs_params['body_html']
		approval_topic.title.should eql sqs_params['topic']['title']
		approval_topic.forum_id.should eql sqs_params['topic']['forum_id']
		approval_topic.user_id.should eql @user.id
	end

	it "should create a dynamo approval post" do
		@account.features.moderate_all_posts.create
		sqs_params = sqs_post_params

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		approval_post = ForumUnpublished.find(:account_id => @account.id, :timestamp => sqs_params['timestamp'])
		approval_post.should_not be_nil
		approval_post.body_html.should eql sqs_params['body_html']
		approval_post.topic_id.should eql @topic.id
		approval_post.user_id.should eql @user.id
	end

	it "should create a dynamo spam topic" do
		sqs_params = sqs_topic_params({:user => @user2})

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		spam_topic = ForumSpam.find(:account_id => @account.id, :timestamp => sqs_params['timestamp'])
		spam_topic.should_not be_nil
		spam_topic.body_html.should eql sqs_params['body_html']
		spam_topic.title.should eql sqs_params['topic']['title']
		spam_topic.forum_id.should eql sqs_params['topic']['forum_id']
		spam_topic.user_id.should eql @user2.id
	end

	it "should create a dynamo spam post" do
		sqs_params = sqs_post_params({:user => @user2})

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		spam_post = ForumSpam.find(:account_id => @account.id, :timestamp => sqs_params['timestamp'])
		spam_post.should_not be_nil
		spam_post.body_html.should eql sqs_params['body_html']
		spam_post.topic_id.should eql @topic.id
		spam_post.user_id.should eql @user2.id
	end

	it "should create a published topic" do
		@account.features.moderate_all_posts.destroy
		sqs_params = sqs_topic_params

		Community::Moderation::QueuedPost.new(sqs_params).analyze
		
		published_topic = @account.topics.find_by_title(sqs_params['topic']['title'])
		published_topic.should_not be_nil
		published_topic.posts.first.body_html.should eql sqs_params['body_html']
		published_topic.forum_id.should eql sqs_params['topic']['forum_id']
		published_topic.user_id.should eql @user.id
	end

	it "should create a published post" do
		sqs_params = sqs_post_params

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		published_post = @account.posts.find_by_body_html(sqs_params['body_html'])
		published_post.should_not be_nil
		published_post.body_html.should eql sqs_params['body_html']
		published_post.topic_id.should eql @topic.id
		published_post.user_id.should eql @user.id
	end

	it "should not create a approval topic when body_html is nil" do
		@account.features.moderate_all_posts.create

		sqs_params = sqs_topic_params.merge({'body_html' => nil})

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		approval_topic = ForumUnpublished.find(:account_id => @account.id, :timestamp => sqs_params['timestamp'])
		approval_topic.should be_nil
	end

	it "should not create a published post when topic is not present" do
		sqs_params = sqs_post_params.merge({
										'topic' => {
											'id' => rand(100)
										}
									})

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		published_post = @account.posts.find_by_body_html(sqs_params['body_html'])
		published_post.should be_nil
	end

	it "should not create a published topic when body_html is nil" do
		sqs_params = sqs_topic_params.merge({'body_html' => ""})

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		published_topic = @account.topics.find_by_title(sqs_params['topic']['title'])
		published_topic.should be_nil
	end

	it "should create a dynamo spam topic when body has email" do
		@account.features.moderate_all_posts.destroy
		@account.features.moderate_posts_with_links.create
		sqs_params = sqs_topic_params.merge({
										"body_html" => "<p>#{Faker::Lorem.paragraph}#{Faker::Internet.email}</p>"
									})

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		spam_topic = ForumUnpublished.find(:account_id => @account.id, :timestamp => sqs_params['timestamp'])
		spam_topic.should_not be_nil
		spam_topic.body_html.should eql sqs_params['body_html']
		spam_topic.title.should eql sqs_params['topic']['title']
		spam_topic.forum_id.should eql sqs_params['topic']['forum_id']
		spam_topic.user_id.should eql @user.id
	end

	it "should create a dynamo spam topic when body has phone numbers" do
		@account.features.moderate_posts_with_links.create
		sqs_params = sqs_topic_params.merge({
										"body_html" => "<p>#{Faker::Lorem.paragraph}#{ForumHelper::PHONE_NUMBERS.sample}</p>"
									})

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		spam_topic = ForumUnpublished.find(:account_id => @account.id, :timestamp => sqs_params['timestamp'])
		spam_topic.should_not be_nil
		spam_topic.body_html.should eql sqs_params['body_html']
		spam_topic.title.should eql sqs_params['topic']['title']
		spam_topic.forum_id.should eql sqs_params['topic']['forum_id']
		spam_topic.user_id.should eql @user.id
	end

	it "should create a dynamo spam topic when body has links" do
		@account.features.moderate_posts_with_links.create
		sqs_params = sqs_topic_params.merge({
										"body_html" => "<p>#{Faker::Lorem.paragraph}#{Faker::Internet.url}</p>"
									})

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		spam_topic = ForumUnpublished.find(:account_id => @account.id, :timestamp => sqs_params['timestamp'])
		spam_topic.should_not be_nil
		spam_topic.body_html.should eql sqs_params['body_html']
		spam_topic.title.should eql sqs_params['topic']['title']
		spam_topic.forum_id.should eql sqs_params['topic']['forum_id']
		spam_topic.user_id.should eql @user.id
	end

	it "should create a published topic when body has whitelisted link" do
		@account.features.moderate_posts_with_links.create
		whitelisted_link = "https://www.youtube.com/watch?v=lbJO8MBCyp4"
		sqs_params = sqs_topic_params.merge({
										"body_html" => "<p>#{Faker::Lorem.paragraph}#{whitelisted_link}</p>"
									})

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		published_topic = @account.topics.find_by_title(sqs_params['topic']['title'])
		published_topic.should_not be_nil
		published_topic.posts.first.body_html.should eql sqs_params['body_html']
		published_topic.forum_id.should eql sqs_params['topic']['forum_id']
		published_topic.user_id.should eql @user.id
	end

	it "should create a published topic when body has no links, email, phone numbers" do
		@account.features.moderate_posts_with_links.create
		sqs_params = sqs_topic_params.merge({
										"body_html" => "<p>#{Faker::Lorem.paragraph}</p>"
									})

		Community::Moderation::QueuedPost.new(sqs_params).analyze

		published_topic = @account.topics.find_by_title(sqs_params['topic']['title'])
		published_topic.should_not be_nil
		published_topic.posts.first.body_html.should eql sqs_params['body_html']
		published_topic.forum_id.should eql sqs_params['topic']['forum_id']
		published_topic.user_id.should eql @user.id
	end


end