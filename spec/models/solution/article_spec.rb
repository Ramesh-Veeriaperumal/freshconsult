require 'spec_helper'

describe Solution::Article do 

	describe "Activities for Solution Articles: " do

		before(:all) do
			@agent1 = add_test_agent
	    	@agent2 = add_test_agent
		    @test_category_meta = create_category
		    @test_folder_meta = create_folder({:visibility => 1, :category_id => @test_category_meta.id})
		end	

		before(:each) do
			@article_meta = create_article({:folder_id => @test_folder_meta.id, :user_id => @agent1.id, :status => "1", :art_type => "1" })
			@article = @article_meta.primary_article
		end

		it "should create activity when article is created" do
			@article.activities.last.description.should eql 'activities.solutions.new_article.long'
			@article.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create activity when article is published" do
			@article.publish!
			@article.activities.last.description.should eql 'activities.solutions.published_article.long'
			@article.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create activity when article is unpublished" do
			@article.publish!
			@article.status = 1
			@article.save
			@article.activities.last.description.should eql 'activities.solutions.unpublished_article.long'
			@article.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create activity when article is destroyed" do
			@article.destroy
			@article.activities.last.description.should eql 'activities.solutions.delete_article.long'
			@article.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create an activity with correct agent" do
			@agent2.make_current
			@article.destroy
			@article.activities.last.user_id.should eql @agent2.id
		end

		it "should create activity of Solution::article notable type" do
			@article.destroy
			@article.activities.last.notable_type.should eql 'Solution::Article'
		end

		it "should create activity with the correct path in activity data" do
			@article.destroy
			@article.activities.last.activity_data[:path].should eql Rails.application.routes.url_helpers.solution_article_path(@article.id)
		end
		
		it "should create activity with the correct title in activity data" do
			@article.destroy
			@article.activities.last.activity_data[:title].should eql @article.title.to_s
		end

		it "should create activity with the correct description" do
			@article.activities.last.description.should eql 'activities.solutions.new_article.long'
			@article.destroy
			@article.activities.last.description.should eql 'activities.solutions.delete_article.long'
		end

		it "should create activity with the correct short description" do
			@article.activities.last.short_descr.should eql 'activities.solutions.new_article.short'
			@article.destroy
			@article.activities.last.short_descr.should eql 'activities.solutions.delete_article.short'
		end

		it "should create only one activity for each action" do
			@article.activities.size.should eql 1
			@article.publish!
			@article.activities.size.should eql 2
			@article.status = 1
			@article.save
			@article.activities.size.should eql 3
			@article.destroy
			@article.activities.size.should eql 4
		end
	end
end