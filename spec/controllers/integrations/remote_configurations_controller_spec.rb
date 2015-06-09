require 'spec_helper'

describe Integrations::RemoteConfigurationsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    dm = DomainMapping.new
    dm.account_id = 5657
    dm.domain = "integrations.freshdesk.com"
    dm.save!

    sm = ShardMapping.new
    sm.account_id = 5657
    sm.shard_name = "shard_1"
    sm.status = 200
    sm.save!
  end

  after(:all) do
    dm = DomainMapping.find_by_domain("integrations.freshdesk.com")
    dm.destroy

    sm = ShardMapping.find_by_account_id(5657)
    sm.destroy
  end

  it "should show page" do
    get :show, fd_cred.merge(
        {
          :id => "uninstall",
          :app => "seoshop",
          :token => "0b9c828e8c4583db1bdb61cd3c28069e",
          :shop_id => "44897",
          :signature => "a9a2db00498a6bcecfbd3b3d43bda8ec",
          :timestamp => "1418822235",
          :language => "en"
        })
    response.body.should =~ /getseoshop.freshdesk.com/
  end

  it "should install seoshop app for the domain" do
    post :create, params.merge(fd_cred).merge(:id => "install")
    response.should redirect_to "https://integrations.freshdesk.com/helpdesk"
    session[:flash][:notice].should =~ /Application is successfully installed in this domain/
    post :create, params.merge(fd_cred).merge(:id => "uninstall")
  end

  it "trying to re-install seoshop app for the domain, gives already installed message" do
    post :create, params.merge(fd_cred).merge(:id => "install")
    post :create, params.merge(fd_cred).merge(:id => "install")
    session[:flash][:notice].should =~ /Application is already installed for this domain/
    post :create, params.merge(fd_cred).merge(:id => "uninstall")
  end

  it "should uninstall seoshop app for the domain" do
    post :create, params.merge(fd_cred).merge(:id => "install")
    post :create, params.merge(fd_cred).merge(:id => "uninstall")
    response.should redirect_to "https://integrations.freshdesk.com/helpdesk"
    session[:flash][:notice].should =~ /Application is successfully uninstalled in this domain/
  end

  it "should give application not available message" do
    post :create, params.merge(fd_cred).merge(:id => "install")
    post :create, params.merge(fd_cred).merge(:id => "uninstall")
    post :create, params.merge(fd_cred).merge(:id => "uninstall")
    session[:flash][:notice].should =~ /Application is not installed in this Domain!/
  end

  it "should say unable to authorize user for seoshop" do
    post :create, {
      :domain => "https://integrations.freshdesk.com",
      :key => "Zi9wklsdf0lEsUepRNYtLFFl0",
      :app_params => {},
      :app => "seoshop",
    }
    session[:flash][:notice].should =~ /Unable to authorize user in Freshdesk..... Please check your domain and API Key...../
  end

  it "should display login msg image if its a freshdesk domain for quickbooks" do
    post :create, {
      :domain => "https://integrations.freshdesk.com",
      :app => "quickbooks",     
    }
    response.body.should =~ /showMsgAndRedirect\(\"login\"/
  end
  
  it "should say invalid freshdesk domain" do
    post :create, {
      :domain => "https://integrate.freshdesk.com",
      :app => "quickbooks"
    }
    session[:flash][:notice].should =~ /This is an invalid freshdesk domain./
  end

  it "Missing param" do
    get :show, fd_cred.merge(
        {
          :id => "uninstall",
          :app => "seoshop",
          :token => "0b9c828e8c4583db1bdb61cd3c28069e",
          :shop_id => "44897",
          :signature => "a9a2db00498a6bcecfbd3b3d43bda8ec",
          :timestamp => "1418822235"
        })
    response.should redirect_to "/500.html"
  end

  def params
    {
      :app => "seoshop",
      :app_params => "{:token=>\"0b9c828e8c4583db1bdb61cd3c28069e\", :language=>\"en\"}"
    }
      # {:language=>\"en\", :token=>\"0b9c828e8c4583db1bdb61cd3c28069e\"}
      # :shop_id => "44897",
      # :signature => "a9a2db00498a6bcecfbd3b3d43bda8ec",
      # :timestamp => "1418822235"
    # }
  end

  def fd_cred
    {
      :domain => "https://integrations.freshdesk.com",
      :key => "RVonTbuWWr6WTDn85"
    }
  end
end
