require 'spec_helper'

describe ForumUnpublished do

	self.use_transactional_fixtures = false

	before(:all) do
		$dynamo = AWS::DynamoDB::ClientV2.new
		Dynamo::CLIENT = $dynamo
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
		@dynamo_topic = create_dynamo_topic("ForumUnpublished", @forum)
		@dynamo_post = create_dynamo_post("ForumUnpublished", @topic)
	end

	before(:each) do
	end

	after(:each) do
		delete_dynamo_posts("ForumUnpublished")
	end

	after(:all) do
		@category.destroy
	end

	it "should return the table name" do
		ForumUnpublished.table_name.should eql "forum_unpublished_test_#{Time.now.utc.strftime('%Y_%m')}"
	end

	it "should create in next month on creation of new topic" do

		new_topic = create_dynamo_topic("ForumUnpublished", @forum)

		ForumUnpublishedNext.find(:account_id => new_topic.account_id, :timestamp => new_topic.timestamp).should_not be_nil

		new_post = create_dynamo_post("ForumUnpublished", @topic)

		ForumUnpublishedNext.find(:account_id => new_post.account_id, :timestamp => new_post.timestamp).should_not be_nil

	end

	it "should update the count on creation of new topic" do

		unpublished_count = SpamCounter.unpublished_count(@account.id)

		create_dynamo_topic("ForumUnpublished", @forum)

		SpamCounter.unpublished_count(@account.id).should eql unpublished_count + 1

		approval_post_count = SpamCounter.count(@topic.id, :unpublished, @account.id)

		create_dynamo_post("ForumUnpublished", @topic)

		SpamCounter.unpublished_count(@account.id).should eql unpublished_count + 2
		SpamCounter.count(@topic.id, :unpublished, @account.id).should eql approval_post_count + 1

	end

	it "should return necessary associations" do
		@dynamo_topic.account.should eql @account
		@dynamo_post.topic_id.should eql @topic.id

		@dynamo_topic.user.should eql @customer
		@dynamo_post.user.should eql @customer

		@dynamo_topic.send("spam?").should be false
	end

	it "should return only last one month topics" do
		not_include_topics = []
		(1..3).each do
			not_include_topics << create_dynamo_topic("ForumUnpublished", @forum, {:timestamp => (Time.now - 2.month).utc.to_f}).attributes
		end

		include_topics = []
		(1..3).each do
			include_topics << create_dynamo_topic("ForumUnpublished", @forum).attributes
		end

		last_month = ForumUnpublished.last_month(@account.id).records.map(&:attributes)

		last_month.should_not =~ not_include_topics
		last_month.should =~ include_topics
	end

	it "should return only topics with timestamp less than given value" do
		create_dynamo_topic("ForumUnpublished", @forum, {:timestamp => (Time.now - 1.day).utc.to_f}).attributes

		last_2_days_posts = []
		for i in [2,3] do 
			last_2_days_posts << create_dynamo_topic("ForumUnpublished", @forum, {:timestamp => (Time.now - i.day).utc.to_f}).attributes
		end

		ForumUnpublished.next(@account.id, (Time.now - 2.day).utc.to_f).records.map(&:attributes).should =~ last_2_days_posts
		
	end

	it "should return all the posts of a given topic" do
		topic_posts = []
		(1..3).each do
			topic_posts << create_dynamo_post("ForumUnpublished", @topic).attributes
		end

		ForumUnpublished.topic_spam(@account.id, @topic.id).records.map(&:attributes).should =~ topic_posts
	end

	it "should delete all the posts of a given topic" do
		topic_posts = []
		(1..3).each do
			topic_posts << create_dynamo_post("ForumUnpublished", @topic).attributes
		end

		ForumUnpublished.topic_spam(@account.id, @topic.id).records.map(&:attributes).should =~ topic_posts

		ForumUnpublished.delete_topic_spam(@account.id, @topic.id)

		ForumUnpublished.topic_spam(@account.id, @topic.id).records.should eql []
	end

	it "should return all the posts by the user" do
		user_posts = []
		(1..3).each do
			user_posts << create_dynamo_post("ForumUnpublished", @topic).attributes
		end
		(1..3).each do
			user_posts << create_dynamo_topic("ForumUnpublished", @forum).attributes
		end
		
		ForumUnpublished.by_user(@account.id, @customer.id, next_user_timestamp(@customer)).records.map(&:attributes).should =~ user_posts
	end

end