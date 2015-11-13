module Integrations
  class GithubWorker < ::BaseWorker

    include Sidekiq::Worker

    sidekiq_options :queue => :github, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(options = {})
      current_account = Account.current
      options = options.symbolize_keys
      operation = options[:operation]
      begin
        installed_app = current_account.installed_applications.find(options.delete(:app_id))
        return unless installed_app
        if(operation == "post_ticket_comments")
          ticket_obj = current_account.tickets.find(options[:local_integratable_id])
          ticket_obj.notes.visible.exclude_source('meta').each do |note|
            options[:act_on_object] = note
            github_service = IntegrationServices::Services::GithubService.new(installed_app, options)
            github_service.receive(:sync_comment_to_github)
          end
        elsif(operation == "update_webhooks")
          github_service = IntegrationServices::Services::GithubService.new(installed_app, options)
          github_service.receive(:delete_webhooks)
          installed_app.configs[:inputs]["secret"] = SecureRandom.hex(20)
          installed_app.save!
          github_service.receive(:add_webhooks)
        else
          github_service = IntegrationServices::Services::GithubService.new(installed_app, options)
          github_service.receive(operation)
        end
      rescue Timeout::TimeoutError => timeouterr
        Rails.logger.debug "Timeout error on github updates - #{timeouterr}"
        NewRelic::Agent.notice_error(timeouterr)
      rescue Exception => error
        Rails.logger.debug "Github rescue updates Failed - #{error}"
        NewRelic::Agent.notice_error(error)
      end
    end

  end
end

