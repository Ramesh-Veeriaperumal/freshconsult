require 'spec_helper'

describe Forum do 

	describe "Activities for Forums: " do

		before(:all) do
			@agent2 = add_test_agent
			@category = create_test_category
		end

		before(:each) do
			@forum = create_test_forum(@category)
		end

		it "should create activity when forum is created" do
			@forum.activities.last.description.should eql 'activities.forums.new_forum.long'
			@forum.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create activity when forum is destroyed" do
			@forum.destroy
			@forum.activities.last.description.should eql 'activities.forums.delete_forum.long'
			@forum.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create an activity with correct agent" do
			@agent.make_current
			@forum.destroy
			@forum.activities.last.user_id.should eql @agent.id
		end

		it "should create activity of Forum notable type" do
			@forum.destroy
			@forum.activities.last.notable_type.should eql 'Forum'
		end

		it "should create activity with the correct path in activity data" do
			@forum.destroy
			@forum.activities.last.activity_data[:path].should eql Rails.application.routes.url_helpers.discussions_forum_path(@forum.id)
		end
		
		it "should create activity with the correct title in activity data" do
			@forum.destroy
			@forum.activities.last.activity_data[:title].should eql @forum.name.to_s
		end

		it "should create activity with the correct description" do
			@forum.activities.last.description.should eql 'activities.forums.new_forum.long'
			@forum.destroy
			@forum.activities.last.description.should eql 'activities.forums.delete_forum.long'
		end

		it "should create activity with the correct short description" do
			@forum.activities.last.short_descr.should eql 'activities.forums.new_forum.short'
			@forum.destroy
			@forum.activities.last.short_descr.should eql 'activities.forums.delete_forum.short'
		end

		it "should create only one activity for each action(create/delete)" do
			@forum.activities.size.should eql 1
			@forum.destroy
			@forum.activities.size.should eql 2
		end
	end
end