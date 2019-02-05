require "datadog/statsd"

class DataDogHelperMethods
  class << self
    def increment_with_tags(counter, tags)
      Rails.logger.info "DATADOG :: Counter: #{counter} :: Tags: [#{tags.join(', ')}]"
      statsd = Datadog::Statsd.new
      statsd.increment(counter, tags: tags)
    rescue => e
      Rails.logger.error "DATADOG ERROR :: Exception: #{e.message} :: Backtrace: #{e.backtrace.join('\n')}"
    end

    def create_login_tags_and_send(login_type, account, user)
      tags = [
        "account_id:#{account.id}",
        "user_type:#{user.helpdesk_agent? ? 'agent' : 'contact' }",
        "sso:#{account.sso_enabled? ? 'yes' : 'no'}",
        "account_state:#{account.subscription.state}",
        "login_type:#{login_type}"
      ]
      increment_with_tags("fd.login", tags)
    end
  end

end