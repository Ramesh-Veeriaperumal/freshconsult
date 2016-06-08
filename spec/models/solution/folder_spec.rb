require 'spec_helper'

describe Solution::Folder do 

	describe "Activities for Solution Folders: " do

		before(:all) do
	    	@agent2 = add_test_agent
	    	@category_meta = create_category
		end	

		before(:each) do
			@folder_meta = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1, :category_id => @category_meta.id } )
			@folder = @folder_meta.primary_folder
		end

		it "should create activity when folder is created" do
			@folder.activities.last.description.should eql 'activities.solutions.new_folder.long'
			@folder.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create activity when folder is destroyed" do
			@folder.destroy
			@folder.activities.last.description.should eql 'activities.solutions.delete_folder.long'
			@folder.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create an activity with correct agent" do
			@agent2.make_current
			@folder.destroy
			@folder.activities.last.user_id.should eql @agent2.id
		end

		it "should create activity of Solution::folder notable type" do
			@folder.destroy
			@folder.activities.last.notable_type.should eql 'Solution::Folder'
		end

		it "should create activity with the correct path in activity data" do
			@folder.destroy
			@folder.activities.last.activity_data[:path].should eql Rails.application.routes.url_helpers.solution_folder_path(@folder)
		end
		
		it "should create activity with the correct title in activity data" do
			@folder.destroy
			@folder.activities.last.activity_data[:title].should eql @folder.name.to_s
		end

		it "should create activity with the correct description" do
			@folder.activities.last.description.should eql 'activities.solutions.new_folder.long'
			@folder.destroy
			@folder.activities.last.description.should eql 'activities.solutions.delete_folder.long'
		end

		it "should create activity with the correct short description" do
			@folder.activities.last.short_descr.should eql 'activities.solutions.new_folder.short'
			@folder.destroy
			@folder.activities.last.short_descr.should eql 'activities.solutions.delete_folder.short'
		end

		it "should create only one activity for each action(create/delete)" do
			@folder.activities.size.should eql 1
			@folder.destroy
			@folder.activities.size.should eql 2
		end
	end

	describe "Activities for Solution Folder Translations: " do

		before(:all) do
  		enable_multilingual
  		@account.make_current
  		@category_meta = create_category
  		@folder_lang_ver = @account.supported_languages_objects.first.to_key
			params = create_solution_folder_alone(solution_default_params(:folder).merge({
								:category_id => @category_meta.id,
					     	:lang_codes => [@folder_lang_ver] + [:primary]
					     }))
      @folder_meta = Solution::Builder.folder(params)
			@folder_translation = @folder_meta.send("#{@folder_lang_ver}_folder")
		end

		it "should create activity when folder translation is created" do
			@folder_translation.activities.last.description.should eql 'activities.solutions.new_folder_translation.long'
			@folder_translation.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create activity of Solution::folder notable type" do
			@folder_translation.activities.last.notable_type.should eql 'Solution::Folder'
		end

		it "should create activity with the correct path in activity data" do
			@folder_translation.activities.last.activity_data[:path].should eql Rails.application.routes.url_helpers.solution_folder_path(@folder_translation)
		end
		
		it "should create activity with the correct title in activity data" do
			@folder_translation.activities.last.activity_data[:title].should eql @folder_translation.name.to_s
		end

		it "should create activity with the correct description" do
			@folder_translation.activities.last.description.should eql 'activities.solutions.new_folder_translation.long'
		end

		it "should create activity with the correct short description" do
			@folder_translation.activities.last.short_descr.should eql 'activities.solutions.new_folder_translation.short'
		end

		it "should create only one activity for each translation created" do
			@folder_translation.activities.size.should eql 1
		end
	end
end