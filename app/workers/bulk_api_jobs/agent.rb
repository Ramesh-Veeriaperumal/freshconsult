module BulkApiJobs
  class Agent < BulkApiJobs::Worker
    sidekiq_options queue: :bulk_api_jobs, retry: 0, failures: :exhausted

    private

      def process_payload(account, payload, partial)
        payload.each_with_index do |agent, index|
          agent_id = agent['id'] = agent['id'].to_i
          record = account.agents.find_by_user_id(agent_id)
          unless record.present?
            agent['success'] = false
            agent['errors'] = 'invalid_id'
            partial = true
            next
          end

          agent['success'] = record.update_attributes(available: agent['ticket_assignment']['available'])
          if agent['success']
            agent['href'] = Rails.application.routes.url_helpers.agent_url(record,
                              host: account.full_domain, protocol: account.url_protocol)
          else
            partial = true
            agent['errors'] = record.errors.messages
          end
        end
        [payload, partial]
      end
  end
end
