require 'spec_helper'

describe ForumCategory do 
	
	describe "Activities for Forum Categories: " do

		before(:all) do
			@agent = add_test_agent
		end

		before(:each) do
			@category = create_test_category
		end

		it "should create activity when forum category is created" do
			@category.activities.last.description.should eql 'activities.forums.new_forum_category.long'
			@category.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create activity when forum category is destroyed" do
			@category.destroy
			@category.activities.last.description.should eql 'activities.forums.delete_forum_category.long'
			@category.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create an activity with correct agent" do
			@agent.make_current
			@category.destroy
			@category.activities.last.user_id.should eql @agent.id
		end

		it "should create activity of ForumCategory notable type" do
			@category.destroy
			@category.activities.last.notable_type.should eql 'ForumCategory'
		end

		it "should create activity with the correct path in activity data" do
			@category.destroy
			@category.activities.last.activity_data[:path].should eql Rails.application.routes.url_helpers.discussion_path(@category.id)
		end
		
		it "should create activity with the correct title in activity data" do
			@category.destroy
			@category.activities.last.activity_data[:title].should eql @category.name.to_s
		end

		it "should create activity with the correct description" do
			@category.activities.last.description.should eql 'activities.forums.new_forum_category.long'
			@category.destroy
			@category.activities.last.description.should eql 'activities.forums.delete_forum_category.long'
		end

		it "should create activity with the correct short description" do
			@category.activities.last.short_descr.should eql 'activities.forums.new_forum_category.short'
			@category.destroy
			@category.activities.last.short_descr.should eql 'activities.forums.delete_forum_category.short'
		end

		it "should create only one activity for each action(create/delete)" do
			@category.activities.size.should eql 1
			@category.destroy
			@category.activities.size.should eql 2
		end

	end
end