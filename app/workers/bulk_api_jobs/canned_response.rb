module BulkApiJobs
  class CannedResponse < BulkApiJobs::Worker
    include CannedResponseConcern

    sidekiq_options queue: :bulk_api_jobs, retry: 0, failures: :exhausted

    private

      def process_create_multiple_payload(payload, succeeded)
        payload = decimal_to_int(payload)
        payload.each_with_index do |canned_response, _index|
          response_code, response = make_internal_api('api/channel/v2/canned_responses', canned_response, current_user_id: User.current.id)
          if response_code == 201
            canned_response['success'] = true
            canned_response['id'] = response['id']
            Sharding.select_shard_of(Account.current.id) do
              ca_response = Account.current.canned_responses.find_by_id(response['id'])
              canned_response['href'] = ca_response.canned_response_url
            end
            succeeded += 1
          else
            canned_response['success'] = false
            canned_response['errors'] = response['errors']
          end
        end
        [payload, succeeded]
      end
  end
end
