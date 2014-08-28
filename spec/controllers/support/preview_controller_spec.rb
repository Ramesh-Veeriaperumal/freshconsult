require 'spec_helper'

describe Support::PreviewController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  it "should show a preview of the support portal" do
    login_admin
    get :index
    response.should render_template("support/preview/index")
  end
end