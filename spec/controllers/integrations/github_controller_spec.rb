require 'spec_helper'
require 'support/github_helper'

include GithubHelper
include Redis::RedisKeys
include Redis::IntegrationsRedis

RSpec.describe Integrations::GithubController do
  setup :activate_authlogic

  before(:all) do
    @agent = add_test_agent(@account)
    key_options = { :account_id => @account.id, :provider => "github"}
    @key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
    Sidekiq::Testing.inline!
  end

  before(:each) do
    log_in(@agent)
    IntegrationServices::Services::Github::GithubRepoResource.any_instance.stubs(:list_repos).returns(list_repo_json)
    IntegrationServices::Services::Github::GithubWebhookResource.any_instance.stubs(:delete_webhook).returns(nil)
    IntegrationServices::Services::Github::GithubWebhookResource.any_instance.stubs(:create_webhook).returns({"id" => 123142452342})
  end

  context "during installation" do
    let(:repositories) { ["orgshreyas2/test1"] }
    before(:context) do
      Redis::KeyValueStore.new(@key_spec, {'app_name' => "github", 'oauth_token' => "RandomString"}.to_json, {:group => :integration, :expire => 300}).set_key
    end
    it "displays settings form with repositories when installing the app" do
      get :new
      expect(response.body).to include("orgshreyas2/test1")
      expect(response.body).to include("install")
    end

    it "the installed app has correct configs" do
      post :install, { :configs => {:repositories => repositories, :can_set_milestones => "1", :github_status_sync => "open", :freshdesk_comment_sync => 1 } }

      installed_app = @account.installed_applications.with_name("github").first
      expect(flash[:notice]).to eql "The integration has been enabled successfully!"
      expect(installed_app).to be_present
      installed_app.destroy
    end

    after(:context) do
          Redis::KeyValueStore.new(@key_spec).remove_key
    end
  end

  context "after installed" do
    repositories = ["orgshreyas2/test1"]
    before(:context) do
      @installed_app = create_installed_applications({:account_id => @account.id, :application_name => "github", :configs => {:inputs => {"repositories" => repositories, "can_set_milestones" => "1", "github_status_sync" => "none", "freshdesk_comment_sync" => "1", "github_comment_sync" => "1", "secret" => "fb0013dd6aca91ffc207a1e88d31d3a5624bccd0", "oauth_token" => "b63b3049e73636fe55ad50115c4b8c5589504a38"} } })
    end
    it "displays settings form with repositories when editing the app" do
      get :edit
      expect(response.body).to include("orgshreyas2/test1")
      expect(response.body).to include("update")
      expect(response.body).to include("cancel")
    end

    it "updates the installed app collectly when updated" do
      post :update, { :configs => {:repositories => repositories, :can_set_milestones => "0", :github_status_sync => "none", :freshdesk_comment_sync => "1" } }
      expect(flash[:notice]).to eql "The integration has been updated successfully!"
      installed_app = @account.installed_applications.with_name("github").first
      expect(installed_app.configs_can_set_milestones).to eql "0"
      expect(installed_app.configs_webhooks["orgshreyas2/test1"]).to eql 123142452342
    end

    it "removes the webhook for deleted repositories" do
      post :update, { :configs => {:repositories => ["org1/adad"], :can_set_milestones => "0", :github_status_sync => "none", :freshdesk_comment_sync => "1" } }
      expect(flash[:notice]).to eql "The integration has been updated successfully!"
      installed_app = @account.installed_applications.with_name("github").first
      expect(installed_app.configs_webhooks["orgshreyas2/test1"]).to be_nil
      expect(installed_app.configs_webhooks["org1/adad"]).to eql 123142452342
      expect(installed_app.configs_can_set_milestones).to eql "0"
    end

    it "handles the webhook correctly" do
      request.env['HTTP_X_HUB_SIGNATURE'] = "sha1=85c4c72b5b0a645a0a842dec6a40b56687c86a31"
      request.env['HTTP_X_GITHUB_EVENT'] = "issue_comment"
      post :webhook_callback, issue_comment_webhook_payload
      expect(response.status).to eql 204
    end

    it "rejects malicious webhook correctly" do
      request.env['HTTP_X_HUB_SIGNATURE'] = "sha1=85c4c72b5b0a645a0a842dec6a40b56687c86a34"
      request.env['HTTP_X_GITHUB_EVENT'] = "issue_comment"
      post :webhook_callback, issue_comment_webhook_payload
      expect(response.status).to eql 404
    end

    after(:context) do
      @installed_app.destroy
    end
  end

end
