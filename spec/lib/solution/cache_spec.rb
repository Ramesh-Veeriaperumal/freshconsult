require 'spec_helper'

include Solution::Cache

describe Solution::Cache do

  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    solution_cache_test_setup
  end

  before(:each) do
    @current_account.clear_solution_categories_from_cache
    @current_account.solution_categories_from_cache
  end

  describe "Cached data" do 

    it "should store correct data in cache" do
      cached_categories = $memcache.get(solutions_cache_key(@current_account))
      cached_categories.each do |c_cat|
        cat = @current_account.solution_categories.find(c_cat['id'])
        c_cat['name'].should eql cat.name
        c_cat['position'].should eql cat.position
        c_cat['folders'].count.should eql cat.folders.count
        c_cat['folders'].each do |c_folder|
          folder =  cat.folders.find(c_folder['id'])
          c_folder['name'].should eql folder.name
          c_folder['article_count'].should eql folder.article_count
        end
        c_cat["portal_solution_categories"].count.should eql cat.portal_solution_categories.count
      end
    end

    it "should get current portal categories" do
      stubs(:current_account).returns(@current_account)
      @portals.each do |portal|
        @category_collection = nil
        portal.solution_categories.where(:is_default => false).count.should eql category_collection(portal)[:current].count
        others_count = @current_account.solution_categories.where(:is_default => false).count - category_collection(portal)[:current].count
        category_collection(portal)[:others].count.should eql others_count
      end
    end
  end

  describe "Cache Invalidation" do

    it "should clear cache" do
      @current_account.clear_solution_categories_from_cache
      check_cache_invalidation(@current_account)
    end

    it "should clear cache on article creation" do
      article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", 
                :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @categories[0].folders[1].id,
                :user_id => @agent.id, :status => "2", :art_type => "1" } )
      check_cache_invalidation(@current_account)
    end

    it "should clear cache on article deletion" do
      @categories[2].folders[3].articles[3].destroy
      check_cache_invalidation(@current_account)
    end

    it "should clear cache when article's folder_id changes" do
      @categories[4].folders[4].articles[4].folder_id = @categories[4].folders[3].id
      @categories[4].folders[4].articles[4].save(:validate => false)
      check_cache_invalidation(@current_account)
    end

    it "should clear cache on folder creation" do
      folder = create_folder({ :name => "#{Faker::Lorem.sentence(3)}", 
                               :description => "#{Faker::Lorem.sentence(3)}",  
                               :visibility => 1,
                               :category_id => @categories[3].id })
      check_cache_invalidation(@current_account)
    end

    it "should clear cache on folder deletion" do
      @categories[4].folders[1].destroy
      check_cache_invalidation(@current_account)
    end

    it "should clear cache when folder name changes" do
      @categories[3].folders[2].name = "folder3_name"
      @categories[3].folders[2].save(validate: false)
      check_cache_invalidation(@current_account)
    end

    it "should clear cache when folder category_id changes" do
      @categories[3].folders[1].category_id = 4
      @categories[3].folders[1].save(validate: false)
      check_cache_invalidation(@current_account)
    end

    it "should clear cache when folder position changes " do
      f = @categories[1].folders.last
      f.position += 1
      f.save(validate: false)
      check_cache_invalidation(@current_account)
    end


    it "should clear cache on category creation" do
      category = create_category( { :name => "#{Faker::Lorem.sentence(3)}",
                                    :description => "#{Faker::Lorem.sentence(3)}", 
                                    :is_default => false } )
      check_cache_invalidation(@current_account)
    end

    it "should clear cache on category deletion" do
      @categories[3].destroy
      check_cache_invalidation(@current_account)
    end

    it "should clear cache when category name changes " do
      @categories[1].reload.name = Faker::Name.name
      @categories[1].save(validate: false)
      check_cache_invalidation(@current_account) 
    end

    it "should clear cache on portal solution category creation" do
      category = create_category( { :name => "#{Faker::Lorem.sentence(3)}",
                                    :description => "#{Faker::Lorem.sentence(3)}", 
                                    :is_default => false } )
      check_cache_invalidation(@current_account)
    end

    it "should clear cache when portal solution category updated " do
      p_sol_cat = @categories[0].portal_solution_categories.last
      p_sol_cat.position += 1
      p_sol_cat.save(validate: false)
      check_cache_invalidation(@current_account)
    end

    it "should clear cache on portal solution category deletion" do
      @categories[4].portal_ids = []
      check_cache_invalidation(@current_account)
    end
  end

  after(:all) do
    ActionController::Base.perform_caching = false
  end
end