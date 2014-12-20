require 'spec_helper'

describe Admin::Social::StreamsController do
  integrate_views
  setup :activate_authlogic  
  self.use_transactional_fixtures = false
  
  before(:all) do
    #@account = create_test_account
  end
  
  before(:each) do
    login_admin
  end
  
  it "should render the admin social streams index page" do
    get "index"
    response.should render_template("admin/social/streams/index.html.erb") 
  end
  
end
