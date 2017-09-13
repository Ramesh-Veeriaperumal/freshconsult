require 'spec_helper'

describe Support::Solutions::FoldersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.launch(:meta_read)
    @account.make_current
    @user = create_dummy_customer
    @now = (Time.now.to_f*1000).to_i
    @test_category_meta = create_category( {:name => "category #{@now}", :description => "new category", :is_default => false} )
    @test_folder_meta1 = create_folder( {:name => "folder1 visible to logged in customers", :description => "new folder", :visibility => 2,
      :category_id => @test_category_meta.id } )
    @test_folder_meta2 = create_folder( {:name => "folder2 visible to agents", :description => "new folder", :visibility => 3,
      :category_id => @test_category_meta.id } )
    @test_folder_meta3 = create_folder( {:name => "folder3 visible to everyone", :description => "new folder", :visibility => 1,
      :category_id => @test_category_meta.id } )
    @test_article_meta1 = create_article( {:title => "article1", :description => "new test article", :folder_id => @test_folder_meta3.id, :status => "2", :art_type => "1" } )
  end

  it "should not show folder1 without logging in" do
    get 'show', id: @test_folder_meta1
    response.body.should =~ /redirected/
    response.body.should_not =~ /folder1 visible to logged in customers/
  end

  it "should not show folder2 without logging in" do
    get 'show', id: @test_folder_meta2
    response.body.should =~ /redirected/
    response.body.should_not =~ /folder2 visible to agents/
  end

  it "should show folder1" do
    log_in(@user)
    get 'show', id: @test_folder_meta1
    response.body.should =~ /folder1 visible to logged in customers/
  end

  it "should not show folder2" do
    log_in(@user)
    get 'show', id: @test_folder_meta2
    response.body.should =~ /redirected/
    response.body.should_not =~ /folder2 visible to agents/
  end

  it "should render 404 for default folder" do
    log_in(@user)
    default_folder_meta = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", 
                             :description => "#{Faker::Lorem.sentence(3)}",  
                             :visibility => 1,
                             :category_id => @test_category_meta.id,
                             :is_default => true } )
    get 'show', id: default_folder_meta.id
    response.status.should eql(404)
  end

  it "should render 404 for folders not visible in current portal" do 
    portal = create_portal
    category = create_category({:portal_ids => [portal.id]})
    folder = create_folder({:visibility => 1, :category_id => category.id })
    get 'show', :id => folder.id
    response.status.should eql(404)
  end

  it "should add meta tags for alterante language versions" do 
    log_in(@user)
    get 'show', id: @test_folder_meta1.id, url_locale: 'en'
    supported_languages = @test_folder_meta1.solution_folder_meta.portal_available_versions
    supported_languages.each do |lang|
      params = { 
                  :id=> @test_folder_meta1.id, 
                  :controller => "support/solutions/folders", 
                  :action => "show", 
                  :url_locale => "en"
                }
      version_url = alternate_version_url(lang, @account.main_portal)
      response.body.should =~ /hreflang="#{lang}" href="#{version_url}"/
    end
  end

  it "should redirect to support solutions home if folder is not visible to user" do
    log_in(@user)
    get 'show', id: @test_folder_meta2
    response.should redirect_to(support_solutions_path)   
  end

  it "should redirect to login path if user is not logged in" do
    get 'show', id: @test_folder_meta1
    response.should redirect_to(support_login_path)  
  end 

  it "should redirect to login path if user is not logged in" do
    get 'show', id: @test_folder_meta2
    response.should redirect_to(support_login_path)  
  end 

  it "should show article if folder is visible to everyone and user is not logged in" do
    get 'show', id: @test_folder_meta3
    response.body.should =~ /folder3 visible to everyone/
    response.body.should =~ /new test article/
  end

  after(:all) do
    @account.rollback(:meta_read)
  end  
end