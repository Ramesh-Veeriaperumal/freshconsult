require 'spec_helper'

include FacebookHelper

describe Social::FacebookPagesController do
  integrate_views
  setup :activate_authlogic
  
  self.use_transactional_fixtures = false
  
  before(:each) do
    log_in(@agent)
  end
  
  describe "#GET index" do
    it "should render the index page to add a new facebook page when no pages are configured" do
      get :index
      response.should render_template("social/facebook_pages/index.html.erb")
    end
    
    
    it "should render the index page and render all the pages associated with the account on authorization" do
      page_id = "#{get_social_id}"
      name = Faker::Name.name
      
      facebook_pages = sample_facebook_pages(page_id, name)
      facebook_page_info = sample_page_info(page_id,name)
      
      Koala::Facebook::OAuth.any_instance.stubs(:get_access_token).returns("23324324")
    
      Koala::Facebook::API.any_instance.stubs(:get_connections).returns(facebook_pages)
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(sample_facebook_profile, facebook_page_info)
      Koala::Facebook::API.any_instance.stubs(:get_picture).returns(sample_page_picture)
      
        get :index, {
          :code => "CODE123"
        }
        response.should render_template("social/facebook_pages/index.html.erb")
        response.template_objects["new_fb_pages"].should_not be_nil
    end
  end
  
  it "should add the selected pages from the user profile to the db" do
    page_id = "#{get_social_id}"
    enable_pages = sample_enable_page_params(page_id)
    
    put :enable_pages, enable_pages
    
    @account.facebook_pages.find_by_page_id(page_id).should_not be_nil
  end
  
  it "should update the page details on calling update" do
    fb_page = create_test_facebook_page
    
    put :update, {
                    "social_facebook_page" => 
                      {
                        "import_visitor_posts"=>"1", 
                        "import_company_posts"=>"0", 
                        "import_dms"=>"1", 
                        "dm_thread_time"=>"99999999999999999", 
                        "product_id"=>"1"
                      }, 
                      "id"=>"#{fb_page.id}"
                  }
    fb_page.reload
    fb_page.product_id.should eql(1)
  end
  
  it "should add a facebook tab and update the page_token_tab of the facebook page on configuring a page tab" do
    fb_page = create_test_facebook_page
    
    page_id = fb_page.page_id
    name = Faker::Name.name
    
    facebook_pages = sample_facebook_pages(page_id, name)
    facebook_pages.first["access_token"] = fb_page.access_token
    
    
    Koala::Facebook::OAuth.any_instance.stubs(:get_access_token).returns("23324324")
  
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(facebook_pages, [])
    Koala::Facebook::API.any_instance.stubs(:delete_connections).returns([])
    Koala::Facebook::API.any_instance.stubs(:put_connections).returns([])
   
    put :edit, {
                "code" => "PAGETABCODE123",
                "id"=>"#{fb_page.id}"
              }
    fb_page.reload
    fb_page.page_token_tab.should eql(fb_page.access_token)
  end
  
  it "should destroy the page on calling delete" do
    fb_page = create_test_facebook_page
    fb_page_id = fb_page.page_id
    
    delete :destroy, {
                      "id"=>"#{fb_page.id}"
                  }
    @account.facebook_pages.find_by_page_id(fb_page_id).should be_nil
  end
end
