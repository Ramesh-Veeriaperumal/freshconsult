require 'spec_helper'

describe Integrations::InstalledApplicationsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  integrate_views

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

    #harvest_application = @account.installed_applications.find_by_application_id(@installaling_applications.find_by_name("harvest").id)
    get :edit, :id => harvest_application.id

    response.should render_template "integrations/installed_applications/edit"
    # p "response.body"
    # p response.body
    response.body.should =~ /Harvest settings/
  end

  it "should uninstall an application" do

    highrise_application_id = @installaling_applications.find_by_name("highrise").id

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

    @account.installed_applications.find_by_application_id(highrise_application_id).should be_nil
      #response.should render_template "integrations/applicatons"
      #response.should redirect_to 'integrations/applications'
      #response.should have_selector('h3', :content => "Integrations")
  end

end


