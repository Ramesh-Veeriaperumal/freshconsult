require 'spec_helper'

describe Mobihelp::SolutionsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @mobihelp_app = create_mobihelp_app
    @user = User.first
    @account.account_additional_settings.update_attributes({:supported_languages => pick_languages(@account.language, 3)})
    @account.reload
    @lang_ver = @account.supported_languages_objects.first
    params = create_solution_category_alone(solution_default_params(:category).merge({
              :lang_codes => [@lang_ver.to_key,:primary]
             }))
    @test_category = Solution::Builder.category(params)
    folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({
              :category_id => @test_category.id,
              :lang_codes => [@lang_ver.to_key,:primary]
             }))
    @test_folder = Solution::Builder.folder(folder_params)
    article_params = params = create_solution_article_alone(solution_default_params(:article, :title).merge({
              :folder_id => @test_folder.id,
              :lang_codes => [@lang_ver.to_key, :primary],
              :status => 2
             }))
    @test_article = Solution::Builder.article(article_params)
    @mobihelp_app_solution = create_mobihelp_app_solutions({:app_id => @mobihelp_app.id, :category_id => @test_category.id, 
                              :position => 1, :account_id => @mobihelp_app.account_id})
    @mobihelp_app_solution.save
  end

  before(:each) do
    @request.env['X-FD-Mobihelp-Auth'] = get_app_auth_key(@mobihelp_app)
    @request.env["HTTP_ACCEPT"] = "application/json"
  end

  it "should fetch updated solution when updates present and the content must be in primary language" do 
    update_since = (1.day.ago).utc.strftime('%FT%TZ') 

    get  :articles, {
      :updated_since => update_since
    }
    result = JSON.parse(response.body)
    result.should have(1).items
    result[0]["folder"].should_not be_nil
    folder_resp = result[0]["folder"]
    article_resp = folder_resp["published_articles"][0]
    folder_resp["name"].should be_eql(@test_folder.primary_folder.name)
    folder_resp["name"].should_not be_eql(@test_folder.send("#{@lang_ver.to_key}_folder").name)
    article_resp["title"].should be_eql(@test_article.primary_article.title)
    article_resp["title"].should_not be_eql(@test_article.send("#{@lang_ver.to_key}_article").title)
    article_resp["description"].should be_eql(@test_article.primary_article.description)
  end

  it "should fetch empty solutions for no updates" do
    update_since = (Time.now + 86400 ).utc.strftime('%FT%TZ') # no updates in 24 hours
    get  :articles, {
      :updated_since => update_since
    }
    result = JSON.parse(response.body)
    result.should have(1).items
    result["no_update"].should be true
  end

  it "should fetch all the solutions when solution updated time is lesser than the mobihelp app updated time" do
    now = Time.now
    @mobihelp_app.name = "Fresh app #{now}"
    @mobihelp_app.save
    update_since = (1.day.ago).utc.strftime('%FT%TZ') 
    get  :articles, {
      :updated_since => update_since
    }
    result = JSON.parse(response.body)
    result.should have(1).items
    result[0]["folder"].should_not be_nil
    result[0]["category"].should be_nil
  end

  it "should fetch solutions with category when the api version is 2 and the content must be in primary language" do 
    @request.env['X-API-Version'] = "2"
    now = Time.now
    @mobihelp_app.name = "Fresh app #{now}"
    @mobihelp_app.save
    update_since = (1.day.ago).utc.strftime('%FT%TZ') 

    get  :articles, {
      :updated_since => update_since
    }
    result = JSON.parse(response.body)
    result.should have(1).items
    result[0]["category"].should_not be_nil
    category_resp = result[0]["category"]
    folder_resp = category_resp["public_folders"][0]
    article_resp = folder_resp["published_articles"][0]
    category_resp["name"].should be_eql(@test_category.primary_category.name)
    category_resp["name"].should_not be_eql(@test_category.send("#{@lang_ver.to_key}_category").name)
    folder_resp["name"].should be_eql(@test_folder.primary_folder.name)
    folder_resp["name"].should_not be_eql(@test_folder.send("#{@lang_ver.to_key}_folder").name)
    article_resp["title"].should be_eql(@test_article.primary_article.title)
    article_resp["title"].should_not be_eql(@test_article.send("#{@lang_ver.to_key}_article").title)
    article_resp["description"].should be_eql(@test_article.primary_article.description)
  end

  it "should render no_update json for no updates and solution updated time is greater than the mobihelp app updated time" do
    update_since = (Time.now+1.day).utc.strftime('%FT%TZ') 

    get  :articles, {
      :updated_since => update_since
    }
    result = JSON.parse(response.body)
    result.should have(1).items
    result["no_update"].should be_truthy
  end

  it "should fetch all solutions when last updated time is not sent" do
    get  :articles
    result = JSON.parse(response.body)
    result.should have(1).items
    result[0]["folder"].should_not be_nil
  end

  it "should fetch all solutions when last updated time is not valid" do
    invalid_date = "23"
      get  :articles, {
      :updated_since => invalid_date
      }
    result = JSON.parse(response.body)
    result.should have(1).items
    result[0]["folder"].should_not be_nil
  end

  describe "It should update the updated_at column of mobihelp_app_solutions on solution CRED operations" do
    before(:all) do
      @mobihelp_category = create_category( {:name => "Mobihelp test new category #{Time.now} #{Faker::Name.name}", :description => "new category", :is_default => false} )
      mobihelp_apps = ((0..2).map do |j|
        mobihelp_app = create_mobihelp_app
        create_mobihelp_app_solutions({:app_id => mobihelp_app.id, :category_id => @mobihelp_category.id, 
                              :position => j+1, :account_id => mobihelp_app.account_id})
        mobihelp_app
      end)
      @mobihelp_app1 = mobihelp_apps.first
      @categories = ((0..2).map do |i|
        category = create_category( {:name => "new category #{Time.now} #{i+1}", :description => "new category", :is_default => false} )
        create_mobihelp_app_solutions({:app_id => @mobihelp_app1.id, :category_id => category.id, 
                              :position => i+1, :account_id => @mobihelp_app1.account_id})
        category
      end)
      @mobihelp_category.reload
      @mobihelp_app1.reload
      @mobihelp_folder = create_folder( {:name => "new folder", :description => "new folder", :visibility => 1,
                                      :category_id => @mobihelp_category.id } )
      @mobihelp_folder.reload
      @user.make_current
      @mobihelp_article = create_article( {:title => "new article", :description => "new test article", 
                          :folder_id => @mobihelp_folder.id, :user_id => @user.id, :status => "2", :art_type => "1" } )
      @mobihelp_article.reload
    end

    before(:each) do |example|
      unless example.metadata[:skip_before]
        @old_app_solutions_updated_at = @mobihelp_category.reload.mobihelp_app_solutions.map(&:updated_at)
        sleep(1)
      end
    end

    after(:each) do |example|
      unless example.metadata[:skip_before]
        compare_updated_at(@old_app_solutions_updated_at, @mobihelp_category.reload.mobihelp_app_solutions.map(&:updated_at))
      end
    end
    
    after(:all) do
      User.reset_current_user
    end

    it "should change updated_at on article creation" do
      test_new_article = create_article( {:title => "new article", :description => "new test article", 
                          :folder_id => @mobihelp_folder.id, :user_id => @user.id, :status => "2", :art_type => "1" } )
    end

    it "should change updated_at on primary article updation" do
      @mobihelp_article.primary_article.title = "Changed name"
      @mobihelp_article.save
    end
    
    it "should change updated_at on publishing primary article" do
      @mobihelp_article.primary_article.update_attribute(:status, 1)
      @mobihelp_article.reload
      @mobihelp_article.publish!
    end
    
    it "should change updated_at on article meta updation" do
      @mobihelp_article.position = @mobihelp_article.position + 1
      @mobihelp_article.save
    end
    
    it "should change updated_at while destroying an article" do
      @mobihelp_article.destroy
    end
      
    it "should change updated_at on folder creation" do
      test_new_folder = create_folder( {:name => "new folder #{Time.now}", :description => "new folder", :visibility => 1,
                                      :category_id => @mobihelp_category.id } )
    end

    it "should change updated_at on folder meta updation" do
      @mobihelp_folder.visibility = 2
      @mobihelp_folder.save
    end
    
    it "should change updated_at on primary folder updation" do
      @mobihelp_folder.primary_folder.name = "Updated folder name"
      @mobihelp_folder.save
    end

    it "should change updated_at while destroying a folder" do
      @mobihelp_folder.destroy
    end
    
    it "should change updated_at on category meta updation" do
      @mobihelp_category.position = 4
      @mobihelp_category.save
    end
    
    it "should change updated_at on primary category updation" do
      @mobihelp_category.primary_category.name = "Updated category name"
      @mobihelp_category.save
    end

    it "should change app's app_solutions on category deletion", :skip_before do
      old_updated_at = @mobihelp_app1.app_solutions.clone.reject {|x| x.category_id == @categories[1].id }.map(&:updated_at)
      sleep(1)
      @categories[1].destroy
      compare_updated_at(old_updated_at, @mobihelp_app1.reload.app_solutions.map(&:updated_at))
    end
    
    describe "It should not update the updated_at column of mobihelp_app_solutions for CRED operations on solution objects that are not primary", :skip_before do
      
      before(:all) do
        @test_mobihelp_folder = create_folder( {:name => "Mobihelp folder", :description => "new folder", :visibility => 1,
                                        :category_id => @mobihelp_category.id } )
        @test_mobihelp_folder.reload
        @user.make_current
        @test_mobihelp_article = create_article( {:title => "Mobihelp test article", :description => "new test article", 
                            :folder_id => @test_mobihelp_folder.id, :user_id => @user.id, :status => "2", :art_type => "1" } )
        @test_mobihelp_article.reload
      end
      
      before(:each) do 
        @app_solutions_updated_at_clone = @mobihelp_category.reload.mobihelp_app_solutions.map(&:updated_at) 
        sleep(1)
      end

      after(:each) do |example|
        check_updated_at_equality(@app_solutions_updated_at_clone, 
              @mobihelp_category.reload.mobihelp_app_solutions.map(&:updated_at))
      end
      
      it "should not change updated_at on category version creation"do
        category_version = @mobihelp_category.send("build_#{@lang_ver.to_key}_category",{:name => "Mobihelp category in #{@lang_ver.code}" } )
        category_version.save
      end
      
      it "should not change updated_at on category version updation" do
        @mobihelp_category.send("#{@lang_ver.to_key}_category").name = "Updating name"
        @mobihelp_category.save
      end
      
      it "should not change updated_at on folder version creation" do
        folder_version = @test_mobihelp_folder.send("build_#{@lang_ver.to_key}_folder",
                  {:name => "Mobihelp folder in #{@lang_ver.code}" } )
        folder_version.save
      end

      it "should not change updated_at on folder version updation" do
        @test_mobihelp_folder.send("#{@lang_ver.to_key}_folder").name = "Updating name"
        @test_mobihelp_folder.save
      end
      
      it "should not change updated_at on article version creation" do
        article_version = @test_mobihelp_article.send("build_#{@lang_ver.to_key}_article",
              {:title => "#{@lang_ver.to_key} title", :description => "#{@lang_ver.to_key} description",
              :status => 2, :user_id => @user.id})
        article_version.save
      end

      it "should not change updated_at on article version updation" do
        @test_mobihelp_article.send("#{@lang_ver.to_key}_article").status = 1
        @test_mobihelp_article
      end

      it "should not change updated_at while destroying an article version" do
        @test_mobihelp_article.send("#{@lang_ver.to_key}_article").destroy
      end
        
      it "should not change updated_at while destroying a folder version" do
        @test_mobihelp_folder.send("#{@lang_ver.to_key}_folder").destroy
      end

      it "should change app's app_solutions on category version deletion" do
        @mobihelp_category.send("#{@lang_ver.to_key}_category").destroy
      end
    end
  end 
end
