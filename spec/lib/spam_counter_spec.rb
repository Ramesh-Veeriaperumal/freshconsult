require 'spec_helper'

describe SpamCounter do

	self.use_transactional_fixtures = false

	before(:all) do
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
	end

	after(:all) do
		@category.destroy
	  	delete_dynamo_posts("ForumSpam")
	  	delete_dynamo_posts("ForumUnpublished")
	end

	it "should return the table name" do
		SpamCounter.table_name.should eql "spam_counter_#{Rails.env[0..3]}_#{Time.now.utc.strftime('%Y_%m')}"
	end

	it "should fetch the total unpublished count" do
		unpublished_count = SpamCounter.unpublished_count
		create_dynamo_topic("ForumUnpublished", @forum)
		create_dynamo_post("ForumUnpublished", @topic)
		SpamCounter.unpublished_count.should eql unpublished_count + 2
	end

	it "should fetch the count of all unpublished topics" do
		unpublished_topics_count = SpamCounter.elaborate_count(:unpublished)[:topics]
		create_dynamo_topic("ForumUnpublished", @forum)
		SpamCounter.elaborate_count(:unpublished)[:topics].should eql unpublished_topics_count + 1
	end

	it "should fetch the count of all unpublished posts" do
		unpublished_posts_count = SpamCounter.elaborate_count(:unpublished)[:posts]
		create_dynamo_post("ForumUnpublished", @topic)
		SpamCounter.elaborate_count(:unpublished)[:posts].should eql unpublished_posts_count + 1
	end

	it "should fetch the count of all unpublished posts in a particular topic" do
		unpublished_posts_count = SpamCounter.count(@topic.id, :unpublished)
		create_dynamo_post("ForumUnpublished", @topic)
		SpamCounter.count(@topic.id, :unpublished).should eql unpublished_posts_count + 1
	end

	it "should fetch the unpublished posts elaborate count" do
		create_dynamo_topic("ForumUnpublished", @forum)
		create_dynamo_post("ForumUnpublished", @topic)
 		unpublished_topics_count = SpamCounter.elaborate_count(:unpublished)[:topics]
 		unpublished_posts_count = SpamCounter.elaborate_count(:unpublished)[:posts]
 		SpamCounter.unpublished_count.should eql unpublished_topics_count + unpublished_posts_count
 	end

 	it "should disregard any negative values when fetching total unpublished count" do
 		unpublished_counters = SpamCounter.find_counters(:unpublished)
 		unpublished_counters.each do |c|
 			c.destroy
 		end	

 		s = SpamCounter.for(:unpublished)
 		s["0"] = -1
 		s.save

 		SpamCounter.unpublished_count.should be >= 0
 	end

 	it "should disregard any negative values when fetching count of all unpublished posts" do
		unpublished_counters = SpamCounter.find_counters(:unpublished)
		unpublished_counters.each do |c|
 			c.destroy
 		end	

		create_dynamo_topic("ForumUnpublished", @forum)
		create_dynamo_post("ForumUnpublished", @topic)

 		s = SpamCounter.for(:unpublished)
 		s[@topic.id.to_s] = -1
 		s.save

		SpamCounter.elaborate_count(:unpublished)[:posts].should eql 0

 	end

 	 it "should disregard any negative values when fetching count of all unpublished posts in a particular topic" do
		unpublished_counters = SpamCounter.find_counters(:unpublished)
		unpublished_counters.each do |c|
 			c.destroy
 		end	

		create_dynamo_topic("ForumUnpublished", @forum)
		create_dynamo_post("ForumUnpublished", @topic)

 		s = SpamCounter.for(:unpublished)
 		s[@topic.id.to_s] = -1
 		s.save

		SpamCounter.count(@topic.id, :unpublished).should eql 0

 	end

	it "should fetch the total spam count" do
		spam_count = SpamCounter.spam_count
		create_dynamo_topic("ForumSpam", @forum)
		create_dynamo_post("ForumSpam", @topic)
		SpamCounter.spam_count.should eql spam_count + 2
	end

	it "should fetch the count of all spam topics" do
		spam_topics_count = SpamCounter.elaborate_count(:spam)[:topics]
		create_dynamo_topic("ForumSpam", @forum)
		SpamCounter.elaborate_count(:spam)[:topics].should eql spam_topics_count + 1
	end

	it "should fetch the count of all spam posts" do
		spam_posts_count = SpamCounter.elaborate_count(:spam)[:posts]
		create_dynamo_post("ForumSpam", @topic)
		SpamCounter.elaborate_count(:spam)[:posts].should eql spam_posts_count + 1
	end

	it "should fetch the count of all spam posts in a particular topic" do
		spam_posts_count = SpamCounter.count(@topic.id, :spam)
		create_dynamo_post("ForumSpam", @topic)
		SpamCounter.count(@topic.id, :spam).should eql spam_posts_count + 1
	end

	it "should fetch the spam posts elaborate count" do
		create_dynamo_topic("ForumSpam", @forum)
		create_dynamo_post("ForumSpam", @topic)
 		spam_topics_count = SpamCounter.elaborate_count(:spam)[:topics]
 		spam_posts_count = SpamCounter.elaborate_count(:spam)[:posts]
 		SpamCounter.spam_count.should eql spam_topics_count + spam_posts_count
 	end

 	it "should disregard any negative values when fetching total spam count" do
 		spam_counters = SpamCounter.find_counters(:spam)
 		spam_counters.each do |c|
 			c.destroy
 		end	

 		s = SpamCounter.for(:spam)
 		s["0"] = -1
 		s.save

 		SpamCounter.spam_count.should be >= 0
 	end

 	it "should disregard any negative values when fetching count of all spam posts" do
		spam_counters = SpamCounter.find_counters(:spam)
		spam_counters.each do |c|
 			c.destroy
 		end	

		create_dynamo_topic("ForumSpam", @forum)
		create_dynamo_post("ForumSpam", @topic)

 		s = SpamCounter.for(:spam)
 		s[@topic.id.to_s] = -1
 		s.save

		SpamCounter.elaborate_count(:spam)[:posts].should eql 0

 	end

 	 it "should disregard any negative values when fetching count of all spam posts in a particular topic" do
		spam_counters = SpamCounter.find_counters(:spam)
		spam_counters.each do |c|
 			c.destroy
 		end	

		create_dynamo_topic("ForumSpam", @forum)
		create_dynamo_post("ForumSpam", @topic)

 		s = SpamCounter.for(:spam)
 		s[@topic.id.to_s] = -1
 		s.save

		SpamCounter.count(@topic.id, :spam).should eql 0

 	end
end