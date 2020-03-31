module BulkApiJobs
  class Agent < BulkApiJobs::Worker
    sidekiq_options queue: :bulk_api_jobs, retry: 0, failures: :exhausted

    private

      def process_update_multiple_payload(payload, succeeded)
        payload.each_with_index do |agent, index|
          agent_id = agent['id'] = agent['id'].to_i
          record = Account.current.agents.find_by_user_id(agent_id)
          unless record.present?
            agent['success'] = false
            agent['errors'] = 'invalid_id'
            next
          end

          agent['success'] = record.update_attributes(available: agent['ticket_assignment']['available'])
          if agent['success']
            agent['href'] = record.agent_url
            succeeded += 1
          else
            agent['errors'] = record.errors.messages
          end
        end
        [payload, succeeded]
      end

      def process_create_multiple_payload(payload, succeeded)
        payload = decimal_to_int(payload)
        payload.each_with_index do |agent, index|
          agent['ticket_scope'] = 1 unless agent['ticket_scope'].present?
          agent['occasional'] = false unless agent['occasional'].present?
          response_code, response = make_internal_api('api/channel/v2/agents', agent, current_user_id: User.current.id)
          if response_code == 201
            agent['success'] = true
            agent['id'] = response['id']
            Sharding.select_shard_of(Account.current.id) do
              user = Account.current.technicians.find_by_id(response['id'])
              agent['href'] = user.agent.agent_url
            end
            succeeded += 1
          else
            agent['success'] = false
            agent['errors'] = response['errors']
          end
        end
        [payload, succeeded]
      end
  end
end
