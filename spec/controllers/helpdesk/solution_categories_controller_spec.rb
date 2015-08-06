require 'spec_helper'

describe Solution::CategoriesController do
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
      c.position.should be_eql(reorder_hash[c.id])
    end          
  end

  it "should create a category with main portal associated if no portal is associated" do
    now = (Time.now.to_f*1000).to_i
    post :create, :solution_category => {:name => "Test category #{now}", :portal_ids => []}

    category = @account.solution_categories.find_by_name("Test category #{now}")
    category.should be_an_instance_of(Solution::Category)
    result = @account.main_portal.portal_solution_categories.find_by_solution_category_id(category.id)
    result.should_not be_nil
  end

  it "should create one record for each specified portal in portal_solution_categories" do

    p1 = create_product({
              :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"
                              })

    p2 = create_product({
                         :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"
                              })
    arr = [p1.portal.id, p2.portal.id]

    post :create, :solution_category => {
                      :name => "Test category with portals",
                      :portal_ids => arr
                    }
                    
    category = @account.solution_categories.find_by_name("Test category with portals")
    result = category.portal_solution_categories.map(&:portal_id)
    result.sort.should eql arr.sort
  end

  it "should not edit a default category" do 
    default_category = @account.solution_categories.find_by_is_default(true)
    get :edit, :id => default_category.id 
    flash[:notice] =~ /category_edit_not_allowed/
  end

  it "should render new page if category create fails" do 
    post :create, :solution_category => {:description => "#{Faker::Lorem.sentence(3)}"}
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
    get :show, :id => @test_category.id
    response.status.should eql 302
    session["flash"][:notice].should eql I18n.t(:'flash.general.access_denied')    
    UserSession.find.destroy
  end

  it "should render edit if category update fails" do 
    put :update, :id => @test_category.id, 
      :solution_category => { :name => nil,
                            :description => "#{Faker::Lorem.sentence(3)}"
                          }
    response.body.should =~ /Edit solution category/i
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
    response.body.should =~ /Edit solution category/i
    name = Faker::Name.name
    put :update, :id => @test_category.id, 
      :solution_category => { :name => "#{name}",
                              :description => "#{Faker::Lorem.sentence(3)}"
                            }
    @account.solution_categories.find_by_name("#{name}").should be_an_instance_of(Solution::Category)    
    response.should redirect_to(solution_category_path(@test_category.id))
  end

  it "should delete a solution category" do
    mobihelp_app = create_mobihelp_app
    mobihelp_app_solution = create_mobihelp_app_solutions({:app_id => mobihelp_app.id, 
                              :category_id => @test_category.id, :position => 1, 
                              :account_id => @account.id})

    delete :destroy, :id => @test_category.id
    @account.solution_categories.find_by_name(@test_category.name).should be_nil
    response.should redirect_to(solution_categories_url)
  end

  it "should render sidebar" do
    xhr :get, :sidebar
    response.should render_template "/solution/categories/_sidebar"
  end
  
  describe "Category meta objects" do
    before(:all) do
      time = Time.now.to_i
      @test_category_for_meta = create_category( {:name => "#{time} test_category_for_meta #{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
      @test_category_for_meta.build_meta.save if @test_category_for_meta.reload.solution_category_meta.blank?
    end

    it "should create a new meta solution category on solution category create" do
      name = Faker::Name.name
      post :create, :solution_category => {:name => "#{name}",
                                         :description => "#{Faker::Lorem.sentence(3)}"
                                        }

      category = @account.solution_categories.find_by_name("#{name}")
      category.should be_an_instance_of(Solution::Category)
      check_meta_integrity(category)
      portal_solution_category = @account.main_portal.portal_solution_categories.find_by_solution_category_id(category.id)
      portal_solution_category.should be_an_instance_of(PortalSolutionCategory)
      portal_solution_category.solution_category_meta_id.should be_eql(portal_solution_category.solution_category_id)
      response.should redirect_to(solution_categories_url)
    end

    it "should create a mobihelp_app_solution with the correct value set for solution_category_meta_id" do
      mobihelp_app = create_mobihelp_app
      mobihelp_app_solution = create_mobihelp_app_solutions({:app_id => mobihelp_app.id, 
                                :category_id => @test_category_for_meta.id, :position => 1, 
                                :account_id => @account.id})
      mobihelp_app_solution.category_id.should be_eql(mobihelp_app_solution.solution_category_meta_id)
    end

    it "should edit a solution category meta on solution category edit" do
      name = Faker::Name.name
      put :update, :id => @test_category_for_meta.id, 
        :solution_category => { :name => "#{name}",
                                :description => "#{Faker::Lorem.sentence(3)}",
                                :is_default => true
                              }
      check_meta_integrity(@test_category_for_meta)
      response.should redirect_to(solution_category_path( @test_category_for_meta))
    end

    it "should destroy meta on category destroy" do
      test_destroy_category = create_category( {:name => "test_destroy_category #{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
      test_destroy_category.build_meta.save if test_destroy_category.reload.solution_category_meta.blank?
      delete :destroy, :id => test_destroy_category.id
      @account.solution_categories.reload.find_by_id(test_destroy_category.id).should be_nil
      @account.solution_category_meta.find_by_id(test_destroy_category.id).should be_nil
      @account.main_portal.portal_solution_categories.find_by_solution_category_id(test_destroy_category.id).should be_nil
    end
  end

  it "should change the position in meta table when category is destroyed" do
    test_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    test_category2 = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    test_category3 = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    test_category.reload.destroy
    check_position(@account, "solution_categories")
  end

end