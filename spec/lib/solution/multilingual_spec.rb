require 'spec_helper'

describe 'Multilingual routing', :type => :controller do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    @user = create_dummy_customer
    @now = (Time.now.to_f*1000).to_i
    @test_category = create_category( {:name => "category #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @test_category2 = create_category( {:name => "category2 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @test_folder1 = create_folder( {:name => "folder1 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
      :category_id => @test_category.id } )
    @test_folder2 = create_folder( {:name => "folder2 visible to agents #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 3,
      :category_id => @test_category.id } )
    @test_folder3 = create_folder( {:name => "folder3 visible to logged in customers#{Faker::Name.name} ", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 2,
      :category_id => @test_category.id } )
    @test_article1 = create_article( {:title => "article1 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1", :user_id => "#{@agent.id}"  } )
    @test_article2 = create_article( {:title => "article2 #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "1", :art_type => "1", :user_id => "#{@agent.id}"  } )
    create_article( {:title => "article1 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
        :status => "2", :art_type => "1", :user_id => "#{@agent.id}"  } )
  end

  before(:each) do
    @account.features.open_solutions.create
  end
  
  after(:each) do |example|
    unless example.metadata[:skip_afer]
      @normal_resp.should eql(@multilingual_resp)
    end
  end

  describe "it should hit the show page of both controllers and the results must be same" do
    it "should hit the show page of both solutions controllers" do
      category_meta = hit_action_and_fetch("Support::Multilingual::SolutionsController", @test_category, "category")
      category = hit_action_and_fetch("Support::SolutionsController", @test_category, "category")
      category_meta.id.should eql(category.id)
    end
    
    it "should hit the show page of both folders controllers" do
      folder_meta = hit_action_and_fetch("Support::Multilingual::Solutions::FoldersController", @test_folder1, "folder")
      category_meta = controller.instance_variable_get("@category")
      folder = hit_action_and_fetch("Support::Solutions::FoldersController", @test_folder1, "folder")
      category = controller.instance_variable_get("@category")
      category_meta.should be_an_instance_of(Solution::CategoryMeta)
      category.should be_an_instance_of(Solution::Category)
      category_meta.id.should eql(category.id)
      folder_meta.id.should eql(folder.id)
    end
    
    it "should hit the show page of both articles controllers" do
      article_meta = hit_action_and_fetch("Support::Multilingual::Solutions::ArticlesController", @test_article1, "article")
      article = hit_action_and_fetch("Support::Solutions::ArticlesController", @test_article1, "article")
      article_meta.id.should eql(article.id)
    end
  end
  
  describe "it should hit the mobihelp actions of both controllers and the result must be the same" do
    before(:all) do
      @mobihelp_app = create_mobihelp_app({:category_ids => [@test_category.id, @test_category2.id]})
      create_mobihelp_app_solutions({:app_id => @mobihelp_app.id, :category_id => @test_category.id,
            :position => 1, :account_id => @mobihelp_app.account_id})
      create_mobihelp_app_solutions({:app_id => @mobihelp_app.id, :category_id => @test_category2.id,
            :position => 2, :account_id => @mobihelp_app.account_id})
      @mobihelp_auth = get_app_auth_key(@mobihelp_app) 
    end
    
    before(:each) do
      @request.env['X-FD-Mobihelp-Auth'] = @mobihelp_auth 
      @request.env["HTTP_ACCEPT"] = "application/json"
    end
    
    it "should hit the thumbs_up of articles controller" do
      check_multilingual_mobihelp_voting(@test_article1, :thumbs_up)
    end
    
    it "should hit the thumbs_down of articles controller" do
      check_multilingual_mobihelp_voting(@test_article1, :thumbs_down)
    end
    
    it "should hit the articles action of solutions controller and the response must be same for v1", :skip_after do
      @account.remove_feature(:solutions_meta_read)
      @controller = Mobihelp::SolutionsController.new
      get :articles
      normal_resp = JSON.parse(response.body)
      category_ids = controller.instance_variable_get("@category_ids")
      @account.add_features(:solutions_meta_read)
      @controller = Mobihelp::Multilingual::SolutionsController.new
      get :articles
      multilingual_resp = JSON.parse(response.body)
      compare_mobihelp_response(normal_resp, multilingual_resp)
      category_meta_ids = controller.instance_variable_get("@category_ids")
      category_ids.should eql(category_meta_ids)
    end
    
    it "should hit the articles action of solutions controller and the response must be same for v2", :skip_after do
      @request.env['X-API-Version'] = "2"
      @account.remove_feature(:solutions_meta_read)
      @controller = Mobihelp::SolutionsController.new
      get :articles
      normal_resp = JSON.parse(response.body)
      category_ids = controller.instance_variable_get("@category_ids")
      @account.add_features(:solutions_meta_read)
      @controller = Mobihelp::Multilingual::SolutionsController.new
      get :articles
      multilingual_resp = JSON.parse(response.body)
      normal_resp.zip(multilingual_resp).each do |normal, multilingual|
        compare_hash_keys(normal, multilingual)
      end
      category_meta_ids = controller.instance_variable_get("@category_ids")
      category_ids.should eql(category_meta_ids)
    end
  end 
  
  it "should check the feature based methods in portal drop for main_portal", :skip_after do
    check_solution_portal_drop_methods(@account.main_portal)
  end
  
  it "should check the feature based methods in portal drop for product portal", :skip_after do
    portal = create_portal
    2.times do 
      category = create_category({:portal_ids => [portal.id]})
      2.times do
        folder = create_folder({:visibility => 1, :category_id => category.id })
        3.times do
          create_article( { :title => "article #{Faker::Name.name}", 
                                    :description => "#{Faker::Lorem.sentence(3)}", :folder_id => folder.id, 
                                    :status => "2", :art_type => "1", :user_id => "#{@agent.id}" } )
        end
      end
    end                              
    check_solution_portal_drop_methods(portal)
  end
end