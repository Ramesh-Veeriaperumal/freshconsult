require 'spec_helper'

describe Integrations::MarketplaceAppsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @applications = Integrations::Application
  end

  before(:each) do
    login_admin
  end

  it "should redirect to installed applications controller" do
    application = @applications.find_by_name("capsule_crm")
    FactoryGirl.build(:installed_application,
      :application_id => application.id,
      :account_id => @account.id,
      :configs => { "title" => "Capsule CRM", "domain" => "abcinternational.capsulecrm.com", "api_key" =>"dda1d82a61ccaba92672616cf1e6f43e", "bcc_drop_box_mail" => "dropbox@50674650.abcinternational.capsulecrm.com" }
    ).save!
    installed_app = @account.installed_applications.with_name('capsule_crm').first
    get :edit, { :id => "capsule_crm" }
    response.should redirect_to "/integrations/installed_applications/" + installed_app.id.to_s + "/edit"
  end

  it "should redirect to application edit url" do
    application = @applications.find_by_name("magento")
    FactoryGirl.build(:installed_application,
      :application_id => application.id,
      :account_id => @account.id,
      :configs => {
        :input => {
          :shops => {
            :shop_name => "test",
            :shop_url => "http://magentotest.ngrok.com",
            :consumer_token => "66aaebb2a5a4610bb3c39b3e5e54cdac",
            :consumer_secret => "f0e4d57b68deafa2ab8bc22c5c2e37b4",
            :oauth_token => "1b27d1d38e1bbe4207182f445515172c",
            :oauth_token_secret => "d10cbf9fdd5d8cfa97a9a6050ed1ce29"
          }
        }
      }
    ).save!
    get :edit, { :id => "magento" }
    response.should redirect_to "/integrations/magento/edit"
  end

  it "should redirect to app settings page" do
    application = @applications.find_by_name("capsule_crm")
    post :install, { :id => "capsule_crm" }
    response.should redirect_to "/integrations/applications/" + application.id.to_s
  end

  it "should render quickbooks c2qb partial" do
    post :install, { :id => 'quickbooks' }
    response.should render_template :partial => "/integrations/applications/_quickbooks_c2qb"
  end

  it "should redirect to application's auth url" do
    post :install, { :id => 'xero'}
    response.should redirect_to "/integrations/xero/authorize"
  end

  it "should redirect to applications index page" do
    post :install, { :id => 'onedrive' }
    @account.installed_applications.with_name('onedrive').first.should_not be_nil
    response.should redirect_to "/integrations/applications"
  end

  it "should redirect to app's oauth url" do
    post :install, { :id => "surveymonkey" }
    response.should redirect_to "https://login.freshpo.com/auth/surveymonkey?origin=id%3D" + @account.id.to_s
  end

  it "should delete the record from installed applications" do
    application = @applications.find_by_name("magento")
    FactoryGirl.build(:installed_application,
      :application_id => application.id,
      :account_id => @account.id,
      :configs => {
        :input => {
          :shops => {
            :shop_name => "test",
            :shop_url => "http://magentotest.ngrok.com",
            :consumer_token => "66aaebb2a5a4610bb3c39b3e5e54cdac",
            :consumer_secret => "f0e4d57b68deafa2ab8bc22c5c2e37b4",
            :oauth_token => "1b27d1d38e1bbe4207182f445515172c",
            :oauth_token_secret => "d10cbf9fdd5d8cfa97a9a6050ed1ce29"
          }
        }
      }
    ).save!
    delete :uninstall, { :id => "magento" }
    expect(response).to be_success
  end

end
