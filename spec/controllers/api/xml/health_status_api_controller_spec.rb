require 'spec_helper'

describe HealthStatusController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  it "should show success in index" do
    get :index, { :format => 'xml' }
    response.body.should =~ /success/
  end
end