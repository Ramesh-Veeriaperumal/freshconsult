require 'spec_helper'
require 'rake'

describe Integrations::GoogleAccountsController do
  integrate_views
	setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do  
    #@account = create_test_account
    @user = add_new_user(@account)
    @user1 = add_test_agent(@account)
    @user2 = add_test_agent(@account)
    @user.deleted = true
    @user.save!
    @account.users.create(:name => "Sathish Babu", :email => "sathish@freshdesk.com")
    @new_application = Factory.build(:application, 
                                     :name => "google_contacts", 
                                     :display_name => "integrations.google_contacts.label", 
                                     :description => "integrations.google_contacts.desc", 
                                     :listing_order => 24, 
                                     :options => { :keys_order=>[:account_settings], 
                                                   :account_settings=> 
                                                      { :type=>:custom, 
                                                        :partial=>"/integrations/applications/google_accounts", 
                                                        :required=>false, 
                                                        :label=>"integrations.google_contacts.form.account_settings", 
                                                        :info=>"integrations.google_contacts.form.account_settings_info"
                                                      }
                                                  },
                                     :application_type => "google_contacts")
    @new_application.save(false)

    @new_installed_application = Factory.build(:installed_application, 
                                               { :application_id => "#{@new_application.id}",
                                                 :account_id => @account.id, 
                                                 :configs => { :inputs => {}}
                                                })
    @new_installed_application.save(false)
    @iapp_id = @new_installed_application.id
    @email = Faker::Internet.email
    @google_account_attr = { :integrations_google_account => { :import_groups => ["6"], 
                                                               :sync_tag => "gmail", 
                                                               :overwrite_existing_user => "1", 
                                                               :sync_type => "0", 
                                                               :sync_group_id => "", 
                                                               :sync_group_name => "Freshdesk Contacts", 
                                                               :id => "", 
                                                               :name => "Freshdesk Test", 
                                                               :email => @email, 
                                                               :token => "1/UFur14aFMvQ_QWMZP8erds1XGmrX0buc_NwRRdp8SMw", 
                                                               :secret => "Rh2dsYkUFdk_V1RWDGVH1rUp"
                                                              }, 
                              :omniauth_origin => "install", 
                              :commit => "Import & Activate", 
                              :iapp_id => "#{@iapp_id}" 
                            }
  end

  before(:each) do
    login_admin
    @request.host = @account.full_domain
  end

  it "should update google accounts" do
    
    post :update, @google_account_attr

    google_account = Integrations::GoogleAccount.find_by_email(@email)
    response.should redirect_to(edit_integrations_installed_application_path(@iapp_id))
  end

  it "should delete google account" do
    google_account = Integrations::GoogleAccount.find_by_email(@email)
    Rails.logger.debug "\n\n $$$$ #{google_account.inspect} \n\n"
    google_account_id = google_account.id

    delete :delete, {:iapp_id => "#{@iapp_id}", :id =>"#{google_account_id}"}

    Integrations::GoogleAccount.find_by_id(google_account_id).should be_nil
  end

  it "should throw error if deletion error occured" do
    invalid_google_account_id = (Integrations::GoogleAccount.last.id if Integrations::GoogleAccount.last) || 0 + 1
    delete :delete, {:iapp_id => "#{@iapp_id}", :id =>"#{invalid_google_account_id}"}

    response.should redirect_to(edit_integrations_installed_application_path(@iapp_id))
  end

  it "should have redirect to application index when iapp_id is nil" do
    @google_account_attr.delete(:iapp_id)
    Rails.logger.debug "\n\n %%%% iapp_id is nil = #{@google_account_attr.inspect} \n\n"
    post :update, @google_account_attr

    google_account = Integrations::GoogleAccount.find_by_email(@email)
    @google_account_attr.merge!(:iapp_id => "#{@iapp_id}")

    response.should redirect_to(:controller=> 'applications', :action => 'index')
  end

  it "should have false for overwrite_existing_user" do
    @google_account_attr[:integrations_google_account].delete(:overwrite_existing_user)
    post :update, @google_account_attr
    google_account = Integrations::GoogleAccount.find_by_email(@email)
    google_account_id = google_account.id

    Integrations::GoogleAccount.find_by_id(google_account_id).should_not be_nil
    Integrations::GoogleAccount.find_by_id(google_account_id).overwrite_existing_user.should be_false
    response.should redirect_to(edit_integrations_installed_application_path(@iapp_id))
  end

  it "should redirect to edit page" do 
    google_account = Integrations::GoogleAccount.find_by_email(@email)
    get :edit, :id => google_account
    response.should render_template "integrations/google_accounts/edit"
  end

  it "should not redirect to edit page" do 
    invalid_google_account_id = ((Integrations::GoogleAccount.last.id if Integrations::GoogleAccount.last) || 0) + 1
    get :edit, :id => invalid_google_account_id
  end

  it "should install google contacts" do
    @inst_obj = Integrations::InstalledApplication.find_by_application_id(4)
    @inst_obj.destroy unless @inst_obj.blank?
    post :update, {"authenticity_token"=>"hEewL7TVXuob8hZNW+8MEqWwgagGACD2Fm8TYTbAsJk=", 
      "integrations_google_account"=>{"import_groups"=>["6"], "sync_tag"=>"gmail", 
      "overwrite_existing_user"=>"1", "sync_group_id"=>"31db62ca8c5c4881", "sync_group_name"=>"Freshdesk Contacts", 
      "id"=>"", "name"=>"Sathish Babu", "email"=>"sathish@freshdesk.com", 
      "token"=>"1/93NJny-KQzpu88PkQ4ClNfnRKk5GrgUZLVxrv9FAgxY", "secret"=>"XHdrB3wpUGReanGX0Dt14DjJ"}, 
      "omniauth_origin"=>"install", "commit"=>  "Import & Activate",
      "controller"=>"integrations/google_accounts", "action"=>"update"}
      Delayed::Job.last.invoke_job
      sleep(15)
      @user.deleted = false
      @user.save!
      @user1.deleted = true 
      @user1.save!
      @user2.external_id = Time.now.utc
      @user2.save!
      load "lib/tasks/google_contacts.rake"
      Rake::Task.define_task(:environment)
      Rake::Task["google_contacts:sync"].invoke
  end
end

