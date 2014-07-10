module Integrations::Jira::WebhookInstaller
  include Integrations::Constants
  
  def self.included(klass)
    klass.send :attr_accessor, :disable_observer
    klass.send :after_commit_on_create, :register_webhook, :if => :jira_app?
    klass.send :after_commit_on_update, :register_webhook, :if => :jira_app?, :unless => :disable_observer
    klass.send :after_destroy,:unregister_webhook, :if => :jira_app?
  end

  def register_webhook
    send_later(:background_task_register)
  end

  def unregister_webhook
  	http_request_proxy = HttpRequestProxy.new
  	Integrations::JiraWebhook.new(self,http_request_proxy).send_later(:delete_webhooks)
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
