require 'spec_helper'

describe Support::SolutionsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.launch(:meta_read)
    @account.make_current
    @user = create_dummy_customer
    @now = (Time.now.to_f*1000).to_i
    @test_category_meta = create_category
    @test_category_meta2 = create_category
    @test_folder_meta1 = create_folder({:visibility => 1, :category_id => @test_category_meta.id })
    @test_folder_meta2 = create_folder({:visibility => 3, :category_id => @test_category_meta.id })
    @test_folder_meta3 = create_folder({:visibility => 2, :category_id => @test_category_meta.id })

    @test_article_meta1 = create_article({:folder_id => @test_folder_meta1.id, :status => "2", :art_type => "1", :user_id => "#{@agent.id}"})
    @test_article_meta2 = create_article({:folder_id => @test_folder_meta1.id, :status => "1", :art_type => "1", :user_id => "#{@agent.id}"})
  end

  before(:each) do
    @account.features.open_solutions.create
  end

  it "should show folder without logging in" do
    get 'index'
    response.body.should =~ /#{@test_folder_meta1.name}/
    response.should render_template("support/solutions/index")
  end

  it "should not show folder without logging in while open solution feature is disabled" do
    @account.features.open_solutions.destroy
    get 'index'
    response.body.should_not =~ /#{@test_folder_meta3.name}/
    response.should redirect_to(login_path)    
  end

  it "should not show folder without logging in" do
    get 'index'
    response.body.should_not =~ /#{@test_folder_meta2.name}/
    response.should redirect_to(login_path)    
  end

  it "should not show solutions" do
    @account.features.open_solutions.destroy
    get 'index'
    response.body.should_not =~ /Solutions/ 
    response.should redirect_to(login_path)
  end

  it "should show category" do
    log_in(@user)
    get 'index'
    response.body.should =~ /#{@test_category_meta.name}/
    response.should render_template("support/solutions/index")
  end

  it "should show folder" do
    log_in(@user)
    get 'index'
    response.body.should =~ /#{@test_folder_meta1.name}/
    response.should render_template("support/solutions/index")
  end

  it "should show folder visible to logged in customers" do
    log_in(@user)
    get 'index'
    response.body.should =~ /#{@test_folder_meta3.name}/
    response.should render_template("support/solutions/index")
  end

  it "should show article" do
    log_in(@user)
    get 'index'
    response.body.should =~ /#{@test_article_meta1.title}/
    response.should render_template("support/solutions/index")
  end

  it "should not show folder visible to agents" do
    log_in(@user)
    get 'index'
    response.body.should_not =~ /#{@test_folder_meta2.name}/
    response.should render_template("support/solutions/index")
  end

  it "should not show article with status as draft" do
    log_in(@user)
    get 'index'
    response.body.should_not =~ /#{@test_article_meta2.title}/
    response.should render_template("support/solutions/index")
  end

  it "should render show page of test category" do 
    log_in(@user)
    get 'show', :id => @test_category_meta.id
    response.body.should =~ /#{@test_category_meta.name}/
    response.body.should_not =~ /#{@test_category_meta2.name}/
    response.should render_template("support/solutions/show")
  end

  it "should render 404 for default category" do
    default_category = @account.solution_category_meta.where(:is_default => true).first
    log_in(@user)
    get 'show', id: default_category.id
    response.status.should eql(404)
  end

  it "should add meta tags for alterante language versions" do
    log_in(@user)   
    get 'show', id: @test_category_meta.id, url_locale: 'en'
    supported_languages = @test_category_meta.portal_available_versions
    supported_languages.each do |lang|
      params = { 
                  :id=> @test_category_meta.id, 
                  :controller => "support/solutions", 
                  :action => "show", 
                  :url_locale => "en"
                }
      version_url = alternate_version_url(lang, @account.main_portal)
      response.body.should =~ /hreflang="#{lang}" href="#{version_url}"/
    end
  end

  after(:all) do
    @account.rollback(:meta_read)
  end

end