require 'spec_helper'

describe Post do 

	describe "Activities for Posts: " do

		before(:all) do
			@agent2 = add_test_agent
			@category = create_test_category
			@forum = create_test_forum(@category)
			@topic = create_test_topic(@forum)
		end

		before(:each) do
			@post = create_test_post(@topic, true)
		end

		it "should create activity when post is created" do
			@post.activities.last.description.should eql 'activities.forums.new_post.long'
			@post.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create activity when post is destroyed" do
			@post.destroy
			@post.activities.last.description.should eql 'activities.forums.delete_post.long'
			@post.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create an activity with correct agent" do
			@agent.make_current
			@post.destroy
			@post.activities.last.user_id.should eql @agent.id
		end

		it "should create activity of Post notable type" do
			@post.destroy
			@post.activities.last.notable_type.should eql 'Post'
		end

		it "should create activity with the correct path in activity data" do
			@post.destroy
			@post.activities.last.activity_data[:path].should eql Rails.application.routes.url_helpers.discussions_topic_path(@post.topic_id)
		end
		
		it "should create activity with the correct title in activity data" do
			@post.destroy
			@post.activities.last.activity_data[:title].should eql @post.to_s
		end

		it "should create activity with the correct description" do
			@post.activities.last.description.should eql 'activities.forums.new_post.long'
			@post.destroy
			@post.activities.last.description.should eql 'activities.forums.delete_post.long'
		end

		it "should create activity with the correct short description" do
			@post.activities.last.short_descr.should eql 'activities.forums.new_post.short'
			@post.destroy
			@post.activities.last.short_descr.should eql 'activities.forums.delete_post.short'
		end

		it "should create only one activity for each action(create/delete)" do
			@post.activities.size.should eql 1
			@post.destroy
			@post.activities.size.should eql 2
		end
	end
end