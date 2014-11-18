require 'spec_helper'

describe Integrations::InstalledApplicationsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    @installaling_applications = Integrations::Application

  end

  before(:each) do
    login_admin
  end

  #adding a new application - capsule crm
  it "should a install a new application" do

    application_id = @installaling_applications.find_by_name("capsule_crm").id

    put :install, {
      :configs => {"title" => "Capsule CRM","domain" => "abcinternational.capsulecrm.com","api_key" =>"dda1d82a61ccaba92672616cf1e6f43e","bcc_drop_box_mail" => "dropbox@50674650.abcinternational.capsulecrm.com"},
      :commit => "Enable", 
      :id => application_id
    }

    @account.installed_applications.find_by_application_id(application_id).should_not be_nil


    contacts_application_id = @installaling_applications.find_by_name("capsule_crm").id

    put :install, {
      :id => contacts_application_id
    }

    @account.installed_applications.find_by_application_id(contacts_application_id).should_not be_nil
    response.should redirect_to 'http://localhost.freshpo.com/integrations/applications'
  end

  it "should install for google contacts" do
    google_app = @account.installed_applications.find_by_application_id(4)
    google_app.destroy if !google_app.nil?

    put :install, {:id => 4}
    response.should redirect_to "/auth/google?origin=install"
  end


  # Updating an application - logmein 
  it "should update a existing application" do

    logmein_application_id = @installaling_applications.find_by_name("logmein").id

    put :install, {
      :configs=>{"title" => "LogMeIn Rescue","company_id" =>  "2152120","password" => "freshdesk@123"},
      :commit=>"Enable", 
      :id=>logmein_application_id
    }

    @account.installed_applications.find_by_application_id(logmein_application_id).should_not be_nil
    logmein_original_application = @account.installed_applications.find_by_application_id(logmein_application_id)

    put :update,  { 
      :configs=>{"title"=>"LogMeIn Rescue", "company_id"=>"2152122", "password"=> "freshdesk-123","authcode"=>"cfg3rqowcv642ko29we35006q32tjiyfj5chrlo3qghmcbdvzwww9lbrhcb28zgs5psvyn15zx2q23poumotrlrz9yuelb1qra9tpdz68eeyy5r8ul0b8tvjylasdzks"},
      :id=>logmein_original_application.id,
      :commit=>"Update",
      :application_id=>@installaling_applications.find_by_name("logmein").id             
    }

    @account.installed_applications.find(logmein_original_application.id).configs.should_not be_eql(logmein_original_application.configs)
  end


  # Edit page
  it "should edit an existing application" do

    harvest_application_id = @installaling_applications.find_by_name("harvest").id

    put :install, {
      :configs => {"title"=>"Harvest", "domain"=>"xyzinternational", "ghostvalue"=>".harvestapp.com", "harvest_note"=>"Freshdesk Ticket # {{ticket.id}}"},
      :commit => "Enable", 
      :id => harvest_application_id
    }

    @account.installed_applications.find_by_application_id(harvest_application_id).should_not be_nil
    harvest_application = @account.installed_applications.find_by_application_id(harvest_application_id)


    get :edit, :id => harvest_application.id

    response.should render_template "integrations/installed_applications/edit"
    response.body.should =~ /Harvest settings/
  end

  it "should fail to uninstall an application" do
    highrise_application_id = @installaling_applications.find_by_name("highrise").id
    Integrations::InstalledApplication.any_instance.stubs(:destroy).raises(StandardError)     

    put :install, {
      :configs => {"domain"=>"freshdesk14", "ghostvalue"=>".highrisehq.com", "api_key"=>"9c0401360bf94a7d0fe9c798a1063ea9"},
      :commit => "Enable", 
      :id => highrise_application_id
    }

    @account.installed_applications.find_by_application_id(highrise_application_id).should_not be_nil
    highrise_application = @account.installed_applications.find_by_application_id(highrise_application_id)

    get :uninstall, {
      :id => highrise_application.id
    }

    @account.installed_applications.find_by_application_id(highrise_application_id).should_not be_nil

  end

  it "should uninstall an application" do

    highrise_application_id = @installaling_applications.find_by_name("highrise").id

    highrise_application = @account.installed_applications.find_by_application_id(highrise_application_id)

    get :uninstall, {
      :id => highrise_application.id
    }

    @account.installed_applications.find_by_application_id(highrise_application_id).should be_nil

  end

  it "jira install should fail with wrong password " do
    application_id = @installaling_applications.find_by_name("jira").id

    put :install, {
        :configs => { "domain" => "https://fresh-desk.atlassian.net", 
                      "title" => "Atlassian Jira", 
                      "username" => "sathappan@freshdesk.com", 
                      "jira_note" => "rspec Testing Ticket", 
                      "password" => "wrong_password" },
        :id => application_id, 
        :commit => "Enable" }

    @account.installed_applications.find_by_application_id(application_id).should be_nil
    response.should redirect_to "/integrations/applications"
  end

  it "jira install should raise exception with too large password" do
    application_id = @installaling_applications.find_by_name("jira").id

    put :install, {
        :configs => { "domain" => "https://fresh-desk.atlassian.net", 
                      "title" => "Atlassian Jira", 
                      "username" => "sathappan@freshdesk.com", 
                      "jira_note" => "rspec Testing Ticket", 
                      "password" => "QwX4vYE25cZcKiqnLbnwHmD2cC9cWn40HT5EnjESaslWTA0lGpr2rlyAiSxq
                                     HwvXDp8wlkW2NsVPAG00WhXsEc5YrWmWFHWP+tWlARHzspmE9dr1uCcYXNPw
                                     dBEPADQcpr2m5ucl4HR7EBH5sVxfeax8czPo0xQSvuHO5qN25R9fwQnRn03+
                                     dngsOjWfJk9Q/zmB9oRJp2EwXeOmeWcDjTaC2FmMumvq8j6ZF4Kms65dnEF5
                                     4y2ruxLHFeg24P0rOmYFwbK+evqLCPW7WSkaQOGKK/5IkfwDaUgJvnJf3SWr
                                     arjGLsJdSjtkDrIXO5nmQ/28Kr6juK2P8WK4AMryuw==" },
        :id => application_id }
    @account.installed_applications.find_by_application_id(application_id).should be_nil
    response.should redirect_to "/integrations/applications"
  end

  it "should install jira" do
    application_id = @installaling_applications.find_by_name("jira").id

    put :install, {
        :configs => { "domain" => "https://fresh-desk.atlassian.net", 
                      "title" => "Atlassian Jira", 
                      "username" => "sathappan@freshdesk.com", 
                      "jira_note" => "rspec Testing Ticket", 
                      "password" => "legolas" },
        :id => application_id, 
        :commit => "Enable" }

    @account.installed_applications.find_by_application_id(application_id).should_not be_nil
    response.should redirect_to "/integrations/applications"
  end

  it "should fail to install shopify" do
    Integrations::InstalledApplication.any_instance.stubs(:save!).raises(StandardError)     
    put :install, {"application_id"=>"", "configs"=>{"shop_name"=>"itsgaurav", "ghostvalue"=>".myshopify.com"}, 
    "commit"=>"Enable", "action"=>"install", "controller"=>"integrations/installed_applications", "id"=>"24"}
    insta_app = @account.installed_applications.find_by_application_id(24)
    insta_app.should be_nil
  end

  it "should fail to install shopify" do
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(false)     
    put :install, {"application_id"=>"", "configs"=>{"shop_name"=>"itsgaurav", "ghostvalue"=>".myshopify.com"}, 
    "commit"=>"Enable", "action"=>"install", "controller"=>"integrations/installed_applications", "id"=>"24"}
    insta_app = @account.installed_applications.find_by_application_id(24)
    insta_app.should be_nil
  end

  it "should install shopify" do
    put :install, {"application_id"=>"", "configs"=>{"shop_name"=>"itsgaurav", "ghostvalue"=>".myshopify.com"}, 
    "commit"=>"Enable", "action"=>"install", "controller"=>"integrations/installed_applications", "id"=>"24"}
    response.location.should eql "http://#{@account.full_domain}/auth/shopify?shop=itsgaurav.myshopify.com&origin=id%3D1"
  end

  it "should fail to update shopify" do
    Integrations::InstalledApplication.any_instance.stubs(:save!).raises(StandardError)     
    inst_id = Integrations::InstalledApplication.find_by_application_id(24).id
    put :update, {"application_id"=>"", "configs"=>{"shop_name"=>"itsgaurav", "ghostvalue"=>".myshopify.com"}, 
    "commit"=>"Update", "action"=>"update", "controller"=>"integrations/installed_applications", "id"=>inst_id}
    insta_app = @account.installed_applications.find_by_application_id(24)
    insta_app.should_not be_nil
  end



  it "should update shopify" do
    inst_id = Integrations::InstalledApplication.find_by_application_id(24).id
    put :update, {"application_id"=>"", "configs"=>{"shop_name"=>"itsgaurav", "ghostvalue"=>".myshopify.com"}, 
    "commit"=>"Update", "action"=>"update", "controller"=>"integrations/installed_applications", "id"=>inst_id}
    response.location.should eql "http://#{@account.full_domain}/auth/shopify?shop=itsgaurav.myshopify.com&origin=id%3D1"
  end

end


