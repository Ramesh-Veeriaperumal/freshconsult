require 'spec_helper'

include Redis::RedisKeys
include Redis::IntegrationsRedis

RSpec.describe Integrations::JiraIssueController do

  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @agent = add_test_agent(@account)
    @account.installed_applications.with_name('jira').destroy_all
    @installed_application = create_installed_application(@account)
    @custom_fields_id_value_map = get_custom_fields
  end

  before(:each) do
    log_in(@agent)
    @ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
  end

  it "fetches jira projects issues" do
    post :fetch_jira_projects_issues
    response.body.should =~ /res_projects/
  end

  it "should create new issue in jira and insert into integrated resources (create)" do
    post :create, create_params
    ir = Integrations::IntegratedResource.find_by_local_integratable_id(@ticket.id)
    ir.should_not be_nil
  end

  it "should delete integrated resources (unlink)" do
    post :create, create_params
    integrated_resource = Integrations::IntegratedResource.find_by_local_integratable_id(@ticket.id)
    post :unlink, unlink_params(integrated_resource)
    ir = Integrations::IntegratedResource.find_by_remote_integratable_id(integrated_resource.remote_integratable_id)
    ir.should be_nil
    response.body.should eql '{"status":"success"}'
  end

  it "should insert into integrated resources (update)" do# failing in master
    post :create, create_params
    integrated_resource = Integrations::IntegratedResource.find_by_local_integratable_id(@ticket.id)
    post :unlink, unlink_params(integrated_resource)
    post :update, update_params(integrated_resource)
    ir = Integrations::IntegratedResource.find_by_remote_integratable_id(integrated_resource.remote_integratable_id)
    ir.should_not be_nil
  end

  it "should delete all integrated resources of remote key (destroy)" do# failing in master
    post :create, create_params
    integrated_resource = Integrations::IntegratedResource.find_by_local_integratable_id(@ticket.id)
    post :destroy, { "remote_integratable_id" => integrated_resource.remote_integratable_id }
    ir = Integrations::IntegratedResource.find_by_remote_integratable_id(integrated_resource.remote_integratable_id)
    ir.should be_nil
  end

  # it "should notify the events and create new user" do
  #   post :create, create_params
  #   integrated_resource = Integrations::IntegratedResource.find_by_local_integratable_id(@ticket.id)
  #   post :notify, notify_params(integrated_resource)
  #   user = User.find_by_email(@installed_application.configs_username)
  #   user.should_not be_nil
  # end

  # it "remove notification redis key" do
  #   post :create, create_params
  #   integrated_resource = Integrations::IntegratedResource.find_by_local_integratable_id(@ticket.id)
  #   redis_key = INTEGRATIONS_JIRA_NOTIFICATION % { :account_id => @account.id, 
  #               :local_integratable_id => integrated_resource.local_integratable_id, 
  #               :remote_integratable_id => integrated_resource.remote_integratable_id }
  #   set_integ_redis_key(redis_key, params)
  #   post :notify, notify_params(integrated_resource)
  #   get_integ_redis_key(redis_key).should be_nil
  # end

  it "remove notification redis key" do# failing in master
    post :create, create_params
    integrated_resource = Integrations::IntegratedResource.find_by_local_integratable_id(@ticket.id)
    redis_key = INTEGRATIONS_JIRA_NOTIFICATION % { :account_id => @account.id, 
                :local_integratable_id => integrated_resource.local_integratable_id, 
                :remote_integratable_id => integrated_resource.remote_integratable_id }
    set_integ_redis_key(redis_key, controller.params)
    webhook_object = Integrations::JiraWebhook.new(notify_params(integrated_resource))
    Integrations::JiraWebhook.any_instance.stubs(:parse_jira_webhook).returns(webhook_object)
    post :notify, notify_params(integrated_resource)
    get_integ_redis_key(redis_key).should be_nil
  end

  it "should throw exception on create" do# failing in master
    @installed_application.destroy
    post :create
    expected_response = '{"errorMessages":["Error exporting ticket to jira issue"]}'
    response.body.should eql expected_response
  end

  it "should throw exception on update" do# failing in master
    @installed_application.destroy
    post :update# where is id
    expected_response = '{"errorMessages":["Error linking the ticket to the jira issue"]}'
    response.body.should eql expected_response
  end

  it "should throw exception on unlink" do# failing in master
    @installed_application.destroy
    post :unlink
    expected_response = '{"errorMessages":["Error unlinking the ticket from the jira issue"]}'
    response.body.should eql expected_response
  end

  it "should throw exception on destroy" do# failing in master
    @installed_application.destroy
    post :destroy# where is id
    expected_response = '{"errorMessages":["Error unlinking the ticket from the jira issue"]}'
    response.body.should eql expected_response
  end

  it "should throw exception on fetch_jira_projects_issues" do# failing in master
    @installed_application.destroy
    post :fetch_jira_projects_issues
    expected_response = '{"errorMessages":["Unable to fetch Projects and issues"]}'
    response.body.should eql expected_response
  end

  it "should throw unauthorized access on notify with invalid params" do
    post :notify
    response.body.should eql "Unauthorized Access"
  end

end