require 'spec_helper'

describe Mobihelp::SolutionsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @mobihelp_app = create_mobihelp_app
    @user = User.first
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = 'sessions/new'
    @request.env['X-FD-Mobihelp-Auth'] = get_app_auth_key(@mobihelp_app)
  end

  it "should fetch empty solutions for no updates" do
    update_since = (Time.now - 86400 ).utc.strftime('%FT%TZ') # no updates in 24 hours
    post  :articles, {
      :auth_key => get_app_auth_key(@mobihelp_app),
      :updated_since => update_since
    }
    JSON.parse(response.body).should have(0).items
  end

  it "should fetch empty the solutions for no updates and solution updated time is greater than the mobihelp app updated time" do
    update_since = Time.now.utc.strftime('%FT%TZ') 
    post  :articles, {
      :auth_key => get_app_auth_key(@mobihelp_app),
      :updated_since => update_since
    }
    JSON.parse(response.body).should have(0).items
  end

  it "should fetch updated solution when updates present" do 
    update_since = Time.now.utc.strftime('%FT%TZ')

    @test_category = create_category( {:name => "new category #{@now}", :description => "new category", :is_default => false} )
    @test_folder = create_folder( {:name => "new folder", :description => "new folder", :visibility => 1,
                                    :category_id => @test_category.id } )
    @test_article = create_article( {:title => "new article", :description => "new test article", :folder_id => @test_folder.id,
                                      :user_id => @user.id, :status => "2", :art_type => "1" } )

    @mobihelp_app.config[:solutions] = @test_category.id
    @mobihelp_app.save

    post  :articles, {
      :auth_key => get_app_auth_key(@mobihelp_app),
      :updated_since => update_since
    }
    JSON.parse(response.body).should have(1).items
  end

  it "should fetch all solutions when last updated time is not sent" do
    post  :articles, {
      :auth_key => get_app_auth_key(@mobihelp_app)
    }
    JSON.parse(response.body).should have(1).items
  end

  it "should fetch all solutions when last updated time is not valid" do
    invalid_date = "23"
      post  :articles, {
      :auth_key => get_app_auth_key(@mobihelp_app),
      :updated_since => invalid_date
      }
    JSON.parse(response.body).should have(1).items
  end

  it "should fetch empty solutions when category id is invalid" do
    update_since = Time.now.utc.strftime('%FT%TZ')
    @mobihelp_app.config[:solutions] = 0
    @mobihelp_app.save
    post  :articles, {
      :auth_key => get_app_auth_key(@mobihelp_app),
      :updated_since => update_since
    }
    JSON.parse(response.body).should have(0).items
  end

end