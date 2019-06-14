require 'timeout'
module Integrations
  class JiraAccountConfig < ::BaseWorker
    include Integrations::Jira::Helper
    include Integrations::Jira::Constant 

    sidekiq_options :queue => :jira_acc_config_updates, :retry => 0, :failures => :exhausted

    JIRA_TIMEOUT = 180

    def perform(options = {}) 
      options.symbolize_keys!
      current_account = Account.current
      operation = options[:operation]
      installed_app = current_account.installed_applications.find(options[:app_id]) unless operation == DELETE_WEBHOOKS
      password = decrypt(options[:password])
      options[:password] = password
      if(operation == UPDATE)
        jiraIssue = Integrations::JiraIssue.new(installed_app)
        tkt_obj = Account.current.tickets.find(options[:local_integratable_id])
        Timeout.timeout(JIRA_TIMEOUT) {
          jiraIssue.update(options,false)
          jiraIssue.construct_attachment_params(options[:integrated_resource]["remote_integratable_id"],tkt_obj ) unless exclude_attachment?(installed_app)
          jiraIssue.push_existing_notes_to_jira(options[:integrated_resource]["remote_integratable_id"], tkt_obj) if allow_notes?(installed_app)
        }
      elsif(operation == LINK_ISSUE)
        jiraIssue = Integrations::JiraIssue.new(installed_app)
        tkt_obj = Account.current.tickets.find(options[:local_integratable_id])
        Timeout.timeout(JIRA_TIMEOUT) {
          jiraIssue.construct_attachment_params(options[:integrated_resource]["remote_integratable_id"],tkt_obj ) unless exclude_attachment?(installed_app)
          jiraIssue.push_existing_notes_to_jira(options[:integrated_resource]["remote_integratable_id"], tkt_obj) if allow_notes?(installed_app)
        }
      else
        jira_webhook = Integrations::JiraWebhook.new(installed_app,HttpRequestProxy.new,options)
        Timeout.timeout(JIRA_TIMEOUT) {
          jira_webhook.safe_send(operation)
        }
      end
    rescue Timeout::Error => timeouterr
      Rails.logger.debug "Timeout error on jira updates - #{timeouterr}  - current_account - #{options}"
      NewRelic::Agent.notice_error(timeouterr,description: "#{options}")
    rescue Exception => error
      Rails.logger.debug "Jira rescue updates Failed - #{error} - current_account - #{options}"
      NewRelic::Agent.notice_error(error,description: "#{options}")
    end

  private

    def decrypt(data)
      unless data.nil?
        private_key = OpenSSL::PKey::RSA.new(File.read("config/cert/private.pem"), "freshprivate")
        decrypted_value = private_key.private_decrypt(Base64.decode64(data))
      end
    end
  end
end