require 'spec_helper'

describe Solution::CategoriesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @now = (Time.now.to_f*1000).to_i
    @test_category = create_category( {:name => "test category #{@now}", :description => "new category", :is_default => false} )
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                       (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end

  it "should create a new solution category" do
    post :create, :solution_category => {:name => "New category #{@now}",
                                       :description => "New category #{@now}"
                                      }
    @account.solution_categories.find_by_name("New category #{@now}").should be_an_instance_of(Solution::Category)
  end

  it "should edit a solution category" do
    get :edit, :id => @test_category.id
    response.body.should =~ /Edit solution category/
    put :update, :id => @test_category.id, 
      :solution_category => { :name => "category #{@now}",
                              :description => "Testing Category #{@now}"
                            }
    @account.solution_categories.find_by_name("category #{@now}").should be_an_instance_of(Solution::Category)
  end

  it "should delete a solution category" do
    delete :destroy, :id => @test_category.id
    @account.solution_categories.find_by_name("category #{@now}").should be_nil
  end

end