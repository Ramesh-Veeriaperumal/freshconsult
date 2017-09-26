require 'spec_helper'
include FreshcallerSpecHelper
include Freshcaller::JwtAuthentication

describe Admin::Freshcaller::SignupController do
	setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @request.host = @account.full_domain
    log_in(@agent)
  end

  context 'When freshcaller signup is successful' do
    before(:context) do 
      @account.add_feature(:freshcaller)
      Freshcaller::Account.where({:account_id => @account.id}).destroy_all
    end
  	it 'should show freshfone signup on navigating to admin/phone' do 
      controller.stubs(:freshcaller_request).returns(freshcaller_account_signup)
      get :index
      response.should redirect_to admin_phone_path
      expect(@account.freshcaller_account.present?).to be true 
      expect(@agent.agent.freshcaller_agent.present?).to be true
      controller.unstub(:freshcaller_request)
  	end
  end


  context 'When freshcaller signup is unsuccessful due to duplicate domain ' do
    before(:context) do 
      @account.add_feature(:freshcaller)
      Freshcaller::Account.where({:account_id => @account.id}).destroy_all
    end
    it 'should show freshfone signup on navigating to admin/phone' do 
      controller.stubs(:freshcaller_request).returns(freshcaller_domain_error)
      get :index
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok])
      response.should render_template("admin/freshcaller/signup/signup_error")
      controller.unstub(:freshcaller_request)
    end
  end


end