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

  it "should fetch empty solutions for no updates" do
    update_since = (Time.now - 86400 ).utc.strftime('%FT%TZ') # no updates in 24 hours
    get  :articles, {
      :updated_since => update_since
    }
    result = JSON.parse(response.body)
    result.should have(1).items
    result["no_update"].should be_true
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

  it "should fetch empty solutions when category id is invalid" do
    update_since = (1.day.ago).utc.strftime('%FT%TZ') 

    dummy_mh_app = create_mobihelp_app
    dummy_solution_category = create_mobihelp_app_solutions({:app_id => dummy_mh_app.id, :category_id => 0, :position => 1, :account_id => dummy_mh_app.account_id})
    
    @request.env['X-FD-Mobihelp-Auth'] = get_app_auth_key(dummy_mh_app)
    
    get  :articles, {
      :updated_since => update_since
    }
    JSON.parse(response.body).should have(0).items
    dummy_mh_app.delete
    dummy_solution_category.delete
  end

end
