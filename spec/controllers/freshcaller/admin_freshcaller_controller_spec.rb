require 'spec_helper'
include FreshcallerSpecHelper
include Freshcaller::JwtAuthentication

describe Admin::FreshcallerController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshcaller_account
    @request.host = @account.full_domain
    log_in(@agent)
  end

  context 'index' do
    it 'should return status 200 on index action' do
      get :index
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok])
    end
    
    it 'should not contain access link to navigate to freshcaller' do
      get :index
      response.body.should =~ /You do not have acces to Freshcaller/
      response.body.should =~ /You can enable access from your Agent setting page./
    end

    it 'should contain access link to navigate to freshcaller' do
      create_test_freshcaller_agent
      get :index
      response.body.should =~ /Manage settings in Freshcaller/
      response.body.should =~ /Buy numbers, setup call queues, IVRs, etc/
    end
  end

  context 'redirect_to_freshcaller' do
    it 'should return 404 if no freshcaller account' do
      @account.freshcaller_account = nil
      get :redirect_to_freshcaller
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:not_found])
    end
    it 'should return status 302 on redirect_to_freshcaller' do
      get :redirect_to_freshcaller
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:found])
    end

    it 'should redirect to freshcaller sso' do
      get :redirect_to_freshcaller
      expect(/sso\/helpkit/).to match(response.redirect_url)
    end
  end
end
