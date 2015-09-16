require 'spec_helper'

describe Mobihelp::SolutionsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @mobihelp_app = create_mobihelp_app
    @user = User.first
  end

  before(:each) do
    @request.env['X-FD-Mobihelp-Auth'] = get_app_auth_key(@mobihelp_app)
    @request.env["HTTP_ACCEPT"] = "application/json"
  end

  it "should fetch updated solution when updates present" do 
    update_since = Time.now.utc.strftime('%FT%TZ')

    @test_category = create_category( {:name => "new category #{Time.now}", :description => "new category", :is_default => false} )
    @test_folder = create_folder( {:name => "new folder", :description => "new folder", :visibility => 1,
                                    :category_id => @test_category.id } )
    @test_article = create_article( {:title => "new article", :description => "new test article", :folder_id => @test_folder.id,
                                      :user_id => @user.id, :status => "2", :art_type => "1" } )

    @mobihelp_app_solution = create_mobihelp_app_solutions({:app_id => @mobihelp_app.id, :category_id => @test_category.id, 
                              :position => 1, :account_id => @mobihelp_app.account_id})
    @mobihelp_app_solution.save

    get  :articles, {
      :updated_since => update_since
    }
    result = JSON.parse(response.body)
    result.should have(1).items
    result[0]["folder"].should_not be_nil
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

  it "should fetch solutions with category when the api version is 2" do 
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
      @mobihelp_article = create_article( {:title => "new article", :description => "new test article", 
                          :folder_id => @mobihelp_folder.id, :user_id => @user.id, :status => "2", :art_type => "1" } )
      @mobihelp_article.reload
    end

    before(:each) do |example|
      unless example.metadata[:skip_before]
        @app_solutions_clone = @mobihelp_category.reload.mobihelp_app_solutions.clone 
        sleep(1)
      end
    end

    after(:each) do |example|
      unless example.metadata[:skip_before]
        compare_updated_at(@app_solutions_clone, @mobihelp_category.reload.mobihelp_app_solutions)
      end
    end

    it "should change updated_at on article creation" do
      test_new_article = create_article( {:title => "new article", :description => "new test article", 
                          :folder_id => @mobihelp_folder.id, :user_id => @user.id, :status => "2", :art_type => "1" } )
    end

    it "should change updated_at on article updation" do
      @mobihelp_article.update_attribute(:status, 1)
    end

    it "should change updated_at while destroying an article" do
      @mobihelp_article.destroy
    end
      
    it "should change updated_at on folder creation" do
      test_new_folder = create_folder( {:name => "new folder #{Time.now}", :description => "new folder", :visibility => 1,
                                      :category_id => @mobihelp_category.id } )
    end

    it "should change updated_at on folder updation" do
      @mobihelp_folder.update_attribute(:visibility, 2)
    end

    it "should change updated_at while destroying a folder" do
      @mobihelp_folder.destroy
    end

    it "should change updated_at on category updation" do
      @mobihelp_category.update_attribute(:name, "Updating name")
    end

    it "should change app's app_solutions on category deletion", :skip_before do
      app_solutions_clone = @mobihelp_app1.app_solutions.clone.reject {|x| x.category_id == @categories[1].id }
      sleep(1)
      @categories[1].destroy
      compare_updated_at(app_solutions_clone, @mobihelp_app1.reload.app_solutions)
    end
  end 
end
