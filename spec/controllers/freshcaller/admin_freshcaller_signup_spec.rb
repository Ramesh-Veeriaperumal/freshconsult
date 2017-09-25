require 'spec_helper'
include FreshcallerSpecHelper
include Freshcaller::JwtAuthentication

describe Admin::FreshfoneController do
	setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @request.host = @account.full_domain
    log_in(@agent)
  end

  context 'when the old account do not have both freshfone and freshcaller account and on old UI' do
    before(:context) do 
      @account.revoke_feature(:freshcaller)
    end
  	it 'should show freshfone signup on navigating to admin/phone' do 
      get :index
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok])
  	end
  end

  context 'when the old account do not have both freshfone and freshcaller account and on new UI' do
    before(:context) do 
      @account.revoke_feature(:freshcaller)
      @agent.toggle_ui_preference unless @agent.is_falcon_pref?
    end
    it 'should show Freshcaller signup on navigating to admin/phone' do 
      get :index
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok])
      response.should render_template ("admin/freshfone/freshcaller_signup")
      response.body.should =~ /Freshdesk provides an integated phone channel through Freshcaller/
      response.body.should =~ /Create new account/
    end
  end

  context 'when the new account do not have both freshfone and freshcaller account and on old UI' do
    before(:context) do 
      @account.add_feature(:freshcaller)
      @agent.toggle_ui_preference if @agent.is_falcon_pref?
    end
    it 'should show warning on navigating to admin/phone' do 
      get :index
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok])
      response.should render_template ("admin/freshfone/freshcaller_signup")
      response.body.should =~ /Freshcaller is only available in the new UI/
    end
  end

  context 'when the new account do not have both freshfone and freshcaller account and on falcon UI' do
    before(:context) do 
      @account.add_feature(:freshcaller)
      @agent.toggle_ui_preference unless @agent.is_falcon_pref?
    end
    it 'should show Freshcaller signup on navigating to admin/phone' do 
      get :index
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok])
      response.should render_template ("admin/freshfone/freshcaller_signup")
      response.body.should =~ /Freshdesk provides an integated phone channel through Freshcaller/
      response.body.should =~ /Create new account/
    end
  end

  context 'when the old account has freshfone account and no freshcaller account and on falcon UI' do
    before(:context) do 
      create_test_freshfone_account
      @account.revoke_feature(:freshcaller)
      @agent.toggle_ui_preference unless @agent.is_falcon_pref?
    end
    it 'should show Freshcaller signup on navigating to admin/phone' do 
      get :index
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok])
      response.should render_template ("admin/freshcaller/signup/signup_error")
      response.body.should =~ /Phone channel is available only in the old UI/
    end
  end
end