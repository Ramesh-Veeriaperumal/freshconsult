require 'spec_helper'

describe HealthCheckController do

  self.use_transactional_fixtures = false
  include APIAuthHelper

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
    clear_json
    stub_s3_writes
  end

  it "should show success in verify_credential" do
    get :verify_credential, { :format => 'xml' }
    response.body.should =~ /success/
  end

  it "should show success in verify_domain" do
    get :verify_domain, { :format => 'xml' }
    response.body.should =~ /success/
  end
end