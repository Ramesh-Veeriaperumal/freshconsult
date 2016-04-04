require 'spec_helper'

describe Admin::RolesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.make_current
  end

  before(:each) do
    login_admin
  end

  it "should list all the roles in the index page" do
    get :index, :format => 'json'
    result = parse_json(response)
    expected = (response.status == 200) && (compare(result.first["role"].keys,APIHelper::ROLE_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

end