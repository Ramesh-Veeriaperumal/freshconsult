require 'spec_helper'

describe Solution::CategoriesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
    @test_category_meta = create_category
    @test_category_meta2 = create_category
    @test_category_meta3 = create_category
    @test_default_category = create_category({:is_default => true})
  end

  before(:each) do
    login_admin
  end

  it "should render category index" do 
    get :index
    response.should render_template("solution/categories/index")
  end

  it "should redirect user with no privilege to login" do 
    session = UserSession.find
    session.destroy
    log_in(@user)
    get :show, :id => @test_category_meta.id
    flash[:notice] =~ I18n.t(:'flash.general.need_login')  
    UserSession.find.destroy
  end

  it "should render a show page of a category" do
    get :show, :id => @test_category_meta.id
    response.body.should =~ /#{@test_category_meta.name}/
  end

  it "should render a new category form" do 
    get :new 
    response.body.should =~ /New solution category/i
    response.should render_template("solution/categories/new")
  end

  it "should reorder categories" do
    categories = @account.main_portal.portal_solution_categories
    count = categories.count
    position_arr = (1..count).to_a.shuffle
    reorder_hash = {}
    categories.each_with_index do |c,i|
      reorder_hash[c.id] = position_arr[i] 
    end    
    put :reorder, :reorderlist => reorder_hash.to_json
    categories.reload
    categories.each do |c|
      c.position.should be_eql(reorder_hash[c.id]) unless c.solution_category_meta.is_default?
    end          
  end

  it "should create a category with main portal associated if no portal is associated" do
    name = "#{Faker::Name.name} #{(Time.now.to_f*1000).to_i}"
    post :create, :solution_category_meta => {
      :primary_category => {
        :name => name
      }
    }
    category = @account.solution_categories.find_by_name(name)
    category_meta = category.solution_category_meta
    category.should be_an_instance_of(Solution::Category)
    result = @account.main_portal.portal_solution_categories.find_by_solution_category_meta_id(category_meta.id)
    result.should_not be_nil
  end

  it "should create one record for each specified portal in portal_solution_categories" do
    p1 = create_product({:portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"})
    p2 = create_product({:portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"})
    arr = [p1.portal.id, p2.portal.id]
    name = "#{Faker::Name.name} #{(Time.now.to_f*1000).to_i}"
    post :create, :solution_category_meta => {
      :portal_ids => arr,
      :primary_category => {
        :name => name
      }
    }
          
    category = @account.solution_categories.find_by_name(name)
    category_meta = category.solution_category_meta
    result = category_meta.portal_solution_categories.map(&:portal_id)
    result.sort.should eql arr.sort
  end

  it "should not edit a default category" do 
    default_category_meta = @account.solution_category_meta.find_by_is_default(true)
    get :edit, :id => default_category_meta.id 
    flash[:notice] =~ /category_edit_not_allowed/
  end

  it "should render new page if category create fails" do 
    post :create, :solution_category_meta => {
      :primary_category => {
        :description => "#{Faker::Lorem.sentence(3)}"
      }
    }
    response.body.should =~ /New solution category/i
    response.should render_template("solution/categories/new")
  end

  it "should not show categories to restricted agent" do
    UserSession.find.destroy
    restricted_agent = add_agent(@account, { :name => Faker::Name.name,
                                            :email => Faker::Internet.email,
                                            :active => 1,
                                            :role => 1,
                                            :agent => 1,
                                            :role_ids => [@account.roles.find_by_name("Agent").id.to_s]                                         
                                            })
    restricted_agent.privileges = 1
    restricted_agent.save
    log_in(restricted_agent)
    get :show, :id => @test_category_meta.id
    response.status.should eql 302
    session["flash"][:notice].should eql I18n.t(:'flash.general.access_denied')    
    UserSession.find.destroy
  end

  it "should render edit if category update fails" do 
    put :update, :id => @test_category_meta.id, 
      :solution_category_meta => { 
        :primary_category => {
          :name => nil,
          :description => "#{Faker::Lorem.sentence(3)}"
        }
      }
    response.should render_template("solution/categories/edit")                         
  end

  it "should create a new solution category" do
    name = Faker::Name.name
    post :create, :solution_category_meta => {
      :primary_category => {
        :name => name,
        :description => "#{Faker::Lorem.sentence(3)}"
      }
    }
    category =  @account.solution_categories.find_by_name("#{name}")
    category_meta = category.solution_category_meta
    category.should be_an_instance_of(Solution::Category)
    response.should redirect_to(solution_category_path(category_meta))
  end

  it "should edit a solution category" do
    get :edit, :id => @test_category_meta.id
    response.body.should =~ /Edit solution category/i
    name = Faker::Name.name
    put :update, :id => @test_category_meta.id, 
      :solution_category_meta => {
        :primary_category => {
          :name => "#{name}",
          :description => "#{Faker::Lorem.sentence(3)}" 
        }
      }
    @account.solution_categories.find_by_name(name).should be_an_instance_of(Solution::Category)    
    response.should redirect_to(solution_all_categories_path)
  end

  it "should delete a solution category" do
    mobihelp_app = create_mobihelp_app
    mobihelp_app_solution = create_mobihelp_app_solutions({:app_id => mobihelp_app.id, 
                              :category_id => @test_category_meta.id, :position => 1, 
                              :account_id => @account.id})

    delete :destroy, :id => @test_category_meta.id
    @account.solution_categories.find_by_name(@test_category_meta.name).should be_nil
    response.should redirect_to(solution_categories_path)
  end

  it "should render sidebar" do
    xhr :get, :sidebar
    response.should render_template "/solution/categories/_sidebar"
  end

  it "should redirect to drafts index page when default category is accessed" do
    category = @account.solution_category_meta.where(:is_default => true).first
    get :show, :id => category.id
    response.should redirect_to(solution_my_drafts_path('all'))
  end

end