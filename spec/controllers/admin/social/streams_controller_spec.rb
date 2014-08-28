require 'spec_helper'

describe Admin::Social::StreamsController do
  setup :activate_authlogic  
  self.use_transactional_fixtures = false
  
  before(:all) do
    RSpec.configuration.account = create_test_account
  end
  
  before(:each) do
    login_admin
  end
  
  it "should render the admin social streams index page" do
    get "index"
    response.should render_template("admin/social/streams/index") 
  end
  
end
