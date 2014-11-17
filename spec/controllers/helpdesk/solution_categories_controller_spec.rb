require 'spec_helper'

describe Solution::CategoriesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
    @now = (Time.now.to_f*1000).to_i
    @test_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @test_category2 = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @test_category3 = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @test_default_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => true} )
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
    get :show, :id => @test_category.id
    flash[:notice] =~ I18n.t(:'flash.general.need_login')  
    UserSession.find.destroy
  end

  it "should render a show page of a category" do
    get :show, :id => @test_category.id
    response.body.should =~ /#{@test_category.name}/
  end

  it "should render a new category form" do 
    get :new 
    response.body.should =~ /New solution category/
    response.should render_template("solution/categories/new")
  end

  it "should reorder categories" do
    categories = @account.solution_categories
    count = categories.count
    position_arr = (1..count).to_a.shuffle
    reorder_hash = {}
    categories.each_with_index do |c,i|
      reorder_hash[c.id] = position_arr[i] 
    end    
    put :reorder, :reorderlist => reorder_hash.to_json
    categories.each do |c|
      c.portal_solution_categories.first.position.should be_eql(reorder_hash[c.id])
    end          
  end  

  it "should not edit a default category" do 
    default_category = @account.solution_categories.find_by_is_default(true)
    get :edit, :id => default_category.id 
    flash[:notice] =~ /category_edit_not_allowed/
  end

  it "should render new page if category create fails" do 
    post :create, :solution_category => {:description => "#{Faker::Lorem.sentence(3)}"}
    response.body.should =~ /New solution category/
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
    get :show, :id => @test_category.id
    response.status.should eql "302 Found"
    response.session["flash"][:notice].should eql I18n.t(:'flash.general.access_denied')    
    UserSession.find.destroy
  end

  it "should render edit if category update fails" do 
    put :update, :id => @test_category.id, 
      :solution_category => { :name => nil,
                            :description => "#{Faker::Lorem.sentence(3)}"
                          }
    response.body.should =~ /Edit solution category/ 
    response.should render_template("solution/categories/edit")                         
  end

  it "should create a new solution category" do
    name = Faker::Name.name
    post :create, :solution_category => {:name => "#{name}",
                                       :description => "#{Faker::Lorem.sentence(3)}"
                                      }

    @account.solution_categories.find_by_name("#{name}").should be_an_instance_of(Solution::Category)
    response.should redirect_to(solution_categories_url)
  end

  it "should edit a solution category" do
    get :edit, :id => @test_category.id
    response.body.should =~ /Edit solution category/
    name = Faker::Name.name
    put :update, :id => @test_category.id, 
      :solution_category => { :name => "#{name}",
                              :description => "#{Faker::Lorem.sentence(3)}"
                            }
    @account.solution_categories.find_by_name("#{name}").should be_an_instance_of(Solution::Category)    
    response.should redirect_to(solution_categories_url)
  end

  it "should delete a solution category" do
    delete :destroy, :id => @test_category.id
    @account.solution_categories.find_by_name(@test_category.name).should be_nil
    response.should redirect_to(solution_categories_url)
  end

end