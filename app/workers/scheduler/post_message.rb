module Scheduler
  class PostMessage < BaseWorker
    sidekiq_options queue: :scheduler_post_message, retry: 5,  failures: :exhausted

    def perform(args)
      args.deep_symbolize_keys!
      payload = args[:payload]
      job_id = payload[:job_id]
      scheduler_client = SchedulerService::Client.new(
        job_id: job_id,
        payload: payload,
        group: payload[:group],
        account_id: payload[:data][:account_id],
        end_point: ::SchedulerClientKeys['end_point'],
        scheduler_type: payload[:data][:scheduler_type]
      )
      response = scheduler_client.schedule_job
      Rails.logger.info "scheduler response message successful job_id:::: #{job_id} :::: #{response}"
      response
    end
  end
end
