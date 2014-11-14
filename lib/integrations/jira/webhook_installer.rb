module Integrations::Jira::WebhookInstaller
  include Integrations::Constants
  
  def self.included(klass)
    klass.send :attr_accessor, :disable_observer
    klass.send :after_commit, :register_webhook_on_create, on: :create , :if => :jira_app?
    klass.send :after_commit, :register_webhook_on_update, on: :update, :if => :jira_app?, :unless => :disable_observer
    klass.send :after_destroy,:unregister_webhook, :if => :jira_app?

    alias :register_webhook_on_create :register_webhook
    alias :register_webhook_on_update :register_webhook
  end

  def register_webhook
    options = {
      :operation => "create_webhooks",
      :app_id => self.id
    }
    Resque.enqueue(Workers::Integrations::JiraAccountUpdates,options)
    
  end

  def unregister_webhook
    options = {
        :username => self.configs_username,
        :password => self.configs_password,
        :domain => self.configs_domain,
        :operation => "delete_webhooks"
      }
      Resque.enqueue(Workers::Integrations::JiraAccountUpdates, options)
  end

  def background_task_register
  	http_request_proxy = HttpRequestProxy.new
  	jira_webhook = Integrations::JiraWebhook.new(self,http_request_proxy)
    jira_webhook.delete_webhooks
    jira_webhook.register_webhooks
  end

  def jira_app?
     self.application.name == APP_NAMES[:jira] if self.application.name
  end

end
