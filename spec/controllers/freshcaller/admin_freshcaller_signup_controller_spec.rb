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
  	it 'should show freshcaller signup on navigating to admin/phone' do
      controller.stubs(:freshcaller_request).returns(freshcaller_account_signup)
      post :create
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
    it 'should show freshcaller signup on navigating to admin/phone' do
      controller.stubs(:freshcaller_request).returns(freshcaller_domain_error)
      post :create
      response.status.should eql(Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok])
      response.should render_template("admin/freshcaller/signup/signup_error")
      controller.unstub(:freshcaller_request)
    end
  end

  context 'When freshcaller linking is initiated' do
    before(:each) do 
      @account.add_feature(:freshcaller)
      Freshcaller::Account.where({:account_id => @account.id}).destroy_all
    end

    after(:each) do
      controller.unstub(:freshcaller_request)
    end
    
    it 'should show freshcaller linked account on navigating to admin/phone' do
      controller.stubs(:freshcaller_request).returns(freshcaller_account_linking)
      post :link , {:email => 'sample@freshdesk.com'}
      expect(Freshcaller::Account.where({:account_id => @account.id}).present?).to be true 
    end

    it 'should show access error on linking account' do 
      post :link, {:email => Faker::Internet.email}
      @freshcaller_response = JSON.parse response.body
      expect(@freshcaller_response.present?).to be true 
      expect(@freshcaller_response['error'].present?).to be true
      @freshcaller_response['error'].should eq("No Access to link Account")
    end

    it 'should show error on linking account' do 
      controller.stubs(:freshcaller_request).returns(freshcaller_account_linking_error)
      post :link, {:email => 'sample@freshdesk.com'}
      @freshcaller_response = JSON.parse response.body
      expect(@freshcaller_response.present?).to be true 
      expect(@freshcaller_response['error'].present?).to be true
      @freshcaller_response['error'].should eq("Account Not found")
    end

  end

end