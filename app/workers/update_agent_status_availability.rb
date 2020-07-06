class UpdateAgentStatusAvailability < BaseWorker
  include Admin::ShiftHelper
  sidekiq_options queue: :update_agent_status_availability, retry: 0, failures: :exhausted

  def perform(args = {})
    args.symbolize_keys!
    request_options = { action_method: :patch, url: build_status_url, body: {}, request_id: args[:request_id] }
    shift_worker_response = perform_shift_request(nil, nil, true, request_options)
    Rails.logger.info "shift_worker_response: #{shift_worker_response.inspect}"
  rescue StandardError => e
    Rails.logger.debug "Error in Shift worker: #{e.inspect}"
    NewRelic::Agent.notice_error(e, description: 'error in update_agent_status_availability worker')
    false
  ensure
    User.reset_current_user
  end

  def build_status_url
    format(AGENT_STATUS_URL, id: User.current.id)
  end
end
