require 'spec_helper'

describe Solution::Category do 

	describe "Activities for Solution Categories: " do

		before(:all) do
	    	@agent2 = add_test_agent
		end	

		before(:each) do
			@category_meta = create_category
			@category = @category_meta.primary_category
		end

		it "should create activity when category is created" do
			@category.activities.last.description.should eql 'activities.solutions.new_solution_category.long'
			@category.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create activity when category is destroyed" do
			@category.destroy
			@category.activities.last.description.should eql 'activities.solutions.delete_solution_category.long'
			@category.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create an activity with correct agent" do
			@agent2.make_current
			@category.destroy
			@category.activities.last.user_id.should eql @agent2.id
		end

		it "should create activity of Solution::Category notable type" do
			@category.destroy
			@category.activities.last.notable_type.should eql 'Solution::Category'
		end

		it "should create activity with the correct path in activity data" do
			@category.destroy
			@category.activities.last.activity_data[:path].should eql Rails.application.routes.url_helpers.solution_category_path(@category)
		end
		
		it "should create activity with the correct title in activity data" do
			@category.destroy
			@category.activities.last.activity_data[:title].should eql @category.name.to_s
		end

		it "should create activity with the correct description" do
			@category.activities.last.description.should eql 'activities.solutions.new_solution_category.long'
			@category.destroy
			@category.activities.last.description.should eql 'activities.solutions.delete_solution_category.long'
		end

		it "should create activity with the correct short description" do
			@category.activities.last.short_descr.should eql 'activities.solutions.new_solution_category.short'
			@category.destroy
			@category.activities.last.short_descr.should eql 'activities.solutions.delete_solution_category.short'
		end

		it "should create only one activity for each action(create/delete)" do
			@category.activities.size.should eql 1
			@category.destroy
			@category.activities.size.should eql 2
		end
	end
end