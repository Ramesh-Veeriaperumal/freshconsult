require 'spec_helper'

describe ForumSpam do

	self.use_transactional_fixtures = false

	before(:all) do
		$dynamo = AWS::DynamoDB::ClientV2.new
		Dynamo::CLIENT = $dynamo
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
		@dynamo_topic = create_dynamo_topic("ForumSpam", @forum)
		@dynamo_post = create_dynamo_post("ForumSpam", @topic)
	end

	before(:each) do
	end

	after(:each) do
		delete_dynamo_posts("ForumSpam")
	end

	after(:all) do
		@category.destroy
	end

	it "should return the table name" do
		ForumSpam.table_name.should eql "forum_spam_test_#{Time.now.utc.strftime('%Y_%m')}"
	end

	it "should create in next month on creation of new topic" do

		new_topic = create_dynamo_topic("ForumSpam", @forum)

		ForumSpamNext.find(:account_id => new_topic.account_id, :timestamp => new_topic.timestamp).should_not be_nil

		new_post = create_dynamo_post("ForumSpam", @topic)

		ForumSpamNext.find(:account_id => new_post.account_id, :timestamp => new_post.timestamp).should_not be_nil

	end

	it "should update the count on creation of new topic" do

		spam_count = SpamCounter.spam_count

		create_dynamo_topic("ForumSpam", @forum)

		SpamCounter.spam_count.should eql spam_count + 1

		spam_post_count = SpamCounter.count(@topic.id, :spam)

		create_dynamo_post("ForumSpam", @topic)

		SpamCounter.spam_count.should eql spam_count + 2
		SpamCounter.count(@topic.id, :spam).should eql spam_post_count + 1

	end

	it "should return necessary associations" do
		@dynamo_topic.account.should eql @account
		@dynamo_post.topic_id.should eql @topic.id

		@dynamo_topic.user.should eql @customer
		@dynamo_post.user.should eql @customer

		@dynamo_topic.send("spam?").should be true
	end

	it "should return only last one month topics" do
		not_include_topics = []
		(1..3).each do
			not_include_topics << create_dynamo_topic("ForumSpam", @forum, {:timestamp => (Time.now - 2.month).utc.to_f}).attributes
		end

		include_topics = []
		(1..3).each do
			include_topics << create_dynamo_topic("ForumSpam", @forum).attributes
		end

		last_month = ForumSpam.last_month.records.map(&:attributes)

		last_month.should_not =~ not_include_topics
		last_month.should =~ include_topics
	end

	it "should return only topics with timestamp less than given value" do
		create_dynamo_topic("ForumSpam", @forum, {:timestamp => (Time.now - 1.day).utc.to_f})

		last_2_days_posts = []
		for i in [2,3] do
			last_2_days_posts << create_dynamo_topic("ForumSpam", @forum, {:timestamp => (Time.now - i.day).utc.to_f}).attributes
		end

		ForumSpam.next((Time.now - 2.day).utc.to_f).records.map(&:attributes).should =~ last_2_days_posts
		
	end

	it "should return all the posts of a given topic" do
		topic_posts = []
		(1..3).each do
			topic_posts << create_dynamo_post("ForumSpam", @topic).attributes
		end

		ForumSpam.topic_spam(@topic.id).records.map(&:attributes).should =~ topic_posts
	end

	it "should delete all the posts of a given topic" do
		topic_posts = []
		(1..3).each do
			topic_posts << create_dynamo_post("ForumSpam", @topic).attributes
		end

		ForumSpam.topic_spam(@topic.id).records.map(&:attributes).should =~ topic_posts

		ForumSpam.delete_topic_spam(@topic.id)

		ForumSpam.topic_spam(@topic.id).records.should eql []
	end

	it "should delete all the posts of a account" do
		(1..3).each do
			create_dynamo_post("ForumSpam", @topic)
		end
		(1..3).each do
			create_dynamo_topic("ForumSpam", @forum)
		end
		
		ForumSpam.delete_account_spam

		ForumSpam.last_month.records.should eql []
	end

end