require 'spec_helper'

describe Integrations::InfusionsoftController do 
  setup :activate_authlogic
  self.use_transactional_fixtures = false

	before(:all) do
    @user = add_test_agent(@account)
  end

  before(:each) do
    log_in(@user) 
  end
     
  it "should redirect to crm custom fields form on successful save" do
    provider = "infusionsoft"
    set_redis_key(provider, infusionsoft_params(provider))
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(:text => "{\"methodResponse\":{\"params\":{\"param\":{\"value\":{\"array\":{\"data\":{\"value\":[{\"struct\":{\"member\":[{\"name\":\"Name\",\"value\":\"customField\"},{\"name\":\"Label\",\"value\":\"custom Field\"}]}}]}}}}}}}",:status => 200)
    get :install, {:controller => "integrations/infusionsoft", :action => "install"}
    response.should render_template("integrations/applications/form/crm_custom_fields_form")
  end

  it "On the fields page the user selected values should be updated to DB and integration enabled message should be shown" do
    post :fields_update, {:controller => "integrations/infusionsoft", :action => "fields_update",
                          :app_name => 'infusionsoft',
                          :account_labels => "Company,Email,Phone 1,State,Company Id,custom",
                          :accounts => ["Company","Email","Phone1","State","CompanyId","_custom"],
                          :contact_labels => "First Name,City,Last Name,Country,custom",
                          :contacts => ["FirstName","City","LastName","Country","_custom"],
                          :contact_custom_fields => "_custom",
                          :account_custom_fields => "_custom",
                          :contact_data_types => "type1",
                          :account_data_types => "type2"
                        }
    flash[:notice].should eql "The integration has been enabled successfully!"
    response.should redirect_to "/integrations/applications"
  end

  it "should show the crm custom fields page on clicking the integration edit button" do
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(:text => "{\"methodResponse\":{\"params\":{\"param\":{\"value\":{\"array\":{\"data\":{\"value\":[{\"struct\":{\"member\":[{\"name\":\"Name\",\"value\":\"customField\"},{\"name\":\"Label\",\"value\":\"custom Field\"}]}}]}}}}}}}",:status =>200)
    get :edit, {:controller =>"integrations/infusionsoft",:action => "edit" ,:app_name =>"infusionsoft"}
    response.should render_template("integrations/applications/form/crm_custom_fields_form")
  end

  it "should get new access token if the response status is 401 on clicking edit" do
    access_token = OAuth2::AccessToken.new(OAuth2::Client.new("token_aaa","secret_aaa"), "token_abc")
    Integrations::InfusionsoftController.any_instance.stubs(:get_oauth2_access_token).returns(access_token)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns({:text => "{\"methodResponse\":{\"params\":{\"param\":{\"value\":{\"array\":{\"data\":{\"value\":[{\"struct\":{\"member\":[{\"name\":\"Name\",\"value\":\"customField\"},{\"name\":\"Label\",\"value\":\"custom Field\"}]}}]}}}}}}}",:status =>401},{:text => "{\"methodResponse\":{\"params\":{\"param\":{\"value\":{\"array\":{\"data\":{\"value\":[{\"struct\":{\"member\":[{\"name\":\"Name\",\"value\":\"customField\"},{\"name\":\"Label\",\"value\":\"custom Field\"}]}}]}}}}}}}",:status =>200})
    get :edit, {:controller => "integrations/infusionsoft",:action => "edit"}
    response.should render_template("integrations/applications/form/crm_custom_fields_form")
  end

  it "should render the integrations main page if the response is other than 200 and 401" do
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(:status => 502)
    get :edit, {:controller => "integrations/infusionsoft" ,:action => "edit"}
    response.should redirect_to "/integrations/applications"
  end

  it "should not memcached if the response status is not equal to 200" do
    @installed_app = @account.installed_applications.with_name('infusionsoft').first
    MemcacheKeys.delete_from_cache("fetch_infusionsoft_users:#{@account.id}:#{@installed_app.id}")
    post :fetch_user, {:controller => "integrations/infusionsoft", :action => "fetch_user", :app_name => "infusionsoft",:domain => "https://api.infusionsoft.com",:rest_url => "/crm/xmlrpc/v1?access_token=", :body => "<?xml version='1.0' encoding='UTF-8'?><methodCall><methodName>DataService.findByField</methodName><params><param><value><string>privateKey</string></value></param><param><value><string>User</string></value></param><param><value><int>1000</int></value></param><param><value><int>0</int></value></param><param><value><string>Id</string></value></param><param><value><string>%</string></value></param><param><value><array><data><value><string>FirstName</string></value></data></array></value></param></params></methodCall>", :content_type => "application/xml", :method=> "post"}
    MemcacheKeys.get_from_cache("fetch_infusionsoft_users:#{@account.id}:#{@installed_app.id}").should eql nil
  end
end