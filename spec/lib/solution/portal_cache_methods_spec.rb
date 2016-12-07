require 'spec_helper'

describe Solution::PortalCacheMethods do

  self.use_transactional_fixtures = false

  before(:all) do
    portal_cache_test_setup
  end

  before(:each) do
    @portal.reload
    @portal.instance_variable_set("@current_customer_folder_ids", nil)
  end

  describe "It should store the correct kbase data in cache based on the logged in user's visibility and in the specified language" do 
    before(:each) do
      Language.reset_current
    end

    it "for logged in users" do
      normal_user = add_new_user(@account)
      normal_user.make_current
      Language.for_current_account.make_current
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:logged_users])
    end

    it "for agents" do
      @new_agent.make_current
      @lang_ver.make_current
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:agents])
    end

    it "for users with companies" do
      company_user = add_new_user(@account, {:customer_id => @companies.first.id})
      company_user.make_current
      Language.for_current_account.make_current
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:company_users])
    end

    after(:each) do
      @portal.solution_categories_from_cache
      cached_categories = @portal.solution_categories_from_cache
      categories_from_db = @portal.solution_category_meta.reject(&:is_default?)
      cached_categories.zip(categories_from_db).each do |cached_category, category_from_db|
        expect(cached_category.id).to be_eql(category_from_db.id)
        expect(cached_category.visible_folders_count).to be_eql(
          category_from_db.solution_folder_meta.visible(User.current).size)
        cached_folders = cached_category.visible_folders
        folders_from_db = category_from_db.solution_folder_meta.visible(User.current)
        cached_folders.zip(folders_from_db).each do |cached_folder, folder_from_db|
          expect(cached_folder.id).to be_eql(folder_from_db.id)
          expect(cached_folder.visible_articles_count).to be_eql(
            folder_from_db.solution_article_meta.published.size)
          cached_articles = cached_folder.visible_articles
          articles_from_db = folder_from_db.solution_article_meta.published
          expect(cached_articles.map(&:id)).to be_eql(articles_from_db.map(&:id))
          cached_articles.each do |cached_article|
            expect(@account.solution_articles.find(
                cached_article.current_child_id).language_id).to be_eql(Language.current.id)
          end
        end
      end
    end
  end

  describe "It should reuse cached data for two different users under the same visibility criteria" do

    before(:all) do
      Language.for_current_account.make_current
    end

    it "for two different logged in users" do
      normal_user_1 = add_new_user(@account)
      normal_user_1.make_current
      @portal.solution_categories_from_cache
      @cache_key_1 = @portal.current_solution_cache_key
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:logged_users])
      @cached_categories_1 = $custom_memcache.get(@cache_key_1, false)
      normal_user_2 = add_new_user(@account)
      normal_user_2.make_current
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:logged_users])
      @cache_key_2 = @portal.current_solution_cache_key
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:logged_users])
      @cached_categories_2 = $custom_memcache.get(@cache_key_2, false)
    end

    it "for two different users belonging to the same company" do
      company_user_1 = add_new_user(@account,{:customer_id => @companies.first.id})
      company_user_1.make_current
      @portal.solution_categories_from_cache
      @cache_key_1 = @portal.current_solution_cache_key
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:company_users])
      @cached_categories_1 = $custom_memcache.get(@cache_key_1, false)
      company_user_2 = add_new_user(@account,{:customer_id => @companies.first.id})
      company_user_2.make_current
      @cache_key_2 = @portal.current_solution_cache_key
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:company_users])
      @cached_categories_2 = $custom_memcache.get(@cache_key_2, false)
    end

    it "for two different users for whom the intersection of company_ids and solution_customer_folders is equal" do
      @account.add_features(:multiple_user_companies)
      @account.reload
      company_user_1 = add_new_contractor(@account, {:company_ids => @companies.map(&:id)})
      company_user_1.make_current
      @portal.instance_variable_set("@current_customer_folder_ids", nil)
      @portal.solution_categories_from_cache
      @cache_key_1 = @portal.current_solution_cache_key
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:company_users])
      @cached_categories_1 = $custom_memcache.get(@cache_key_1, false)
      company_ids = @companies.map(&:id) + [create_company.id]
      company_user_2 = add_new_contractor(@account, {:company_ids => company_ids})
      company_user_2.make_current
      @cache_key_2 = @portal.current_solution_cache_key
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:company_users])
      @cached_categories_2 = $custom_memcache.get(@cache_key_2, false)
      @account.remove_feature(:multiple_user_companies)
    end

    it "for two different agents" do
      agent1 = add_test_agent(@account,  {:role => @account.roles.first.id})
      agent1.make_current
      @portal.solution_categories_from_cache
      @cache_key_1 = @portal.current_solution_cache_key
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:agents])
      @cached_categories_1 = $custom_memcache.get(@cache_key_1, false)
      agent2 = add_test_agent(@account,  {:role => @account.roles.first.id})
      agent2.make_current
      @cache_key_2 = @portal.current_solution_cache_key
      expect(@portal.current_visibility_key).to be_eql(@visibility_keys[:agents])
      @cached_categories_2 = $custom_memcache.get(@cache_key_2, false)
    end

    after(:each) do
      expect(@cache_key_1).to be_eql(@cache_key_2)
      expect(@cached_categories_1).to be_eql(@cached_categories_2)
      @cached_categories_1.zip(@cached_categories_2).each do |cached_category_1, cached_category_2|
        expect(cached_category_1.visible_folders_count).to be_eql(cached_category_2.visible_folders_count)
        expect(cached_category_1.visible_folders).to be_eql(cached_category_2.visible_folders)
        cached_category_1.visible_folders.zip(cached_category_2.visible_folders).each do |cached_folder_1, cached_folder_2|
          expect(cached_folder_1.visible_articles_count).to be_eql(cached_folder_2.visible_articles_count)
          expect(cached_folder_1.visible_articles).to be_eql(cached_folder_2.visible_articles) 
        end
      end
    end
  end

  describe "Cached object's drop methods should get evaluated exactly like their db counterparts" do
    before(:all) do
      @portal.reload
      @portal.instance_variable_set("@current_customer_folder_ids", nil)
      Language.for_current_account.make_current
      @new_agent.make_current
      @portal.solution_categories_from_cache
      @cached_categories = $custom_memcache.get(@portal.current_solution_cache_key, false)
    end

    it "for a category object" do
      @cached_object = @cached_categories.last.to_liquid
      @object_from_db = @account.solution_category_meta.find(@cached_object.id).to_liquid
    end

    it "for a folder object" do
      @cached_object = @cached_categories.last.visible_folders.first.to_liquid
      @object_from_db = @account.solution_folder_meta.find(@cached_object.id).to_liquid
    end

    it "for an article object" do
      cached_folder = @cached_categories.last.visible_folders.first
      @cached_object = cached_folder.visible_articles.first.to_liquid
      @object_from_db = @account.solution_article_meta.find(@cached_object.id).to_liquid
    end

    after(:each) do
      current_drop_class = @object_from_db.class
      current_cache_methods = (current_drop_class.const_defined?("CACHE_METHODS") ? current_drop_class::CACHE_METHODS : [])
      current_drop_getters = (current_drop_class.public_instance_methods(false).reject do |meth_name| 
        (current_cache_methods.include?(meth_name) || 
          meth_name.to_s.match(/default_url|cache|context|excerpt|related|\?/))
      end)
      current_drop_getters.each do |meth_name|
        cached_object_meth_value = @cached_object.send(meth_name)
        if cached_object_meth_value.is_a?(Array)
          expect(@cached_object.send(meth_name)).to match_array(@object_from_db.send(meth_name))
        else
          expect(@cached_object.send(meth_name)).to be_eql(@object_from_db.send(meth_name))
        end
      end
      current_cache_methods.each do |meth_name|
        if meth_name.to_s.include?("count")
          expect(@cached_object.send("#{meth_name}_from_cache")).to be_eql(@object_from_db.send(meth_name))
        else
          expect(@cached_object.send("#{meth_name}_from_cache").map(&:id)).to be_eql(
            @object_from_db.send(meth_name).map(&:id))
        end
      end
      (current_drop_class.liquid_attributes - [:object_id]).each do |liquid_attr|
        expect(@cached_object[liquid_attr]).to be_eql(@object_from_db[liquid_attr])
      end
    end
  end

end