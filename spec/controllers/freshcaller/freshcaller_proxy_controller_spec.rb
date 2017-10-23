
require 'spec_helper'
include FreshcallerSpecHelper
include Freshcaller::JwtAuthentication

describe FreshcallerProxyController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  context 'fetch without freshcaller_account' do
    before(:each) do
      @request.host = @account.full_domain
      log_in(@agent)
    end
    it 'should return status 400 on fetch action' do
      post :fetch, freshcaller_proxy_params
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_request])
    end
  end
  context 'fetch with freshcaller_account' do
    before(:each) do
      create_test_freshcaller_account
      @request.host = @account.full_domain
      log_in(@agent)
    end
    it 'should return status 400 on fetch action without params' do
      post :fetch
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_request])
    end

    it 'should return status 200 on fetch action with all params' do
      FreshcallerProxyController.any_instance.stubs(:fetch_response => valid_freshcaller_proxy_response)
      post :fetch, freshcaller_proxy_params
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok])
    end
  end
end
