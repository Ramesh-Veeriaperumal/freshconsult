require 'timeout'

class Workers::Integrations::JiraAccountUpdates
	extend Resque::AroundPerform

	@queue = "jira_updates"
	JIRA_TIMEOUT = 180

	def self.perform(options = {}) 
		current_account = Account.current
		operation = options[:operation]
		installed_app = current_account.installed_applications.find(options[:app_id]) unless operation == "delete_webhooks"
		password = decrypt(options[:password])
		options[:password] = password
		begin
			if(operation == "update")
				jiraIssue = Integrations::JiraIssue.new(installed_app)
				Timeout.timeout(JIRA_TIMEOUT) {
					jiraIssue.update(options,false)
				}
			else
				jira_webhook = Integrations::JiraWebhook.new(installed_app,HttpRequestProxy.new,options)
				Timeout.timeout(JIRA_TIMEOUT) {
					jira_webhook.send(operation)
				}
				
			end
			rescue Timeout::Error => timeouterr
        	Rails.logger.debug "Timeout error on jira updates - #{timeouterr}"
        	NewRelic::Agent.notice_error(timeouterr)
			rescue Exception => error
			Rails.logger.debug "Jira rescue updates Failed - #{error}"
			NewRelic::Agent.notice_error(error)
		end
	end

	private

	def self.decrypt(data)
      unless data.nil?
        private_key = OpenSSL::PKey::RSA.new(File.read("config/cert/private.pem"), "freshprivate")
        decrypted_value = private_key.private_decrypt(Base64.decode64(data))
      end
    end
end