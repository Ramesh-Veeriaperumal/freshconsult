require 'spec_helper'

describe HealthCheckController do

  self.use_transactional_fixtures = false
  include APIAuthHelper

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
    stub_s3_writes
  end

  it "should show success in index" do
    get :index, { :format => 'xml' }
    response.body.should =~ /success/
  end
end