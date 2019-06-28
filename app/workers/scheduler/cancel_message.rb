module Scheduler
  class CancelMessage < BaseWorker
    sidekiq_options queue: :scheduler_cancel_message, retry: 5,  failures: :exhausted

    def perform(args)
      args = args.deep_symbolize_keys
      group_name = args[:group_name]
      job_id_list = args[:job_ids] || []
      responses = job_id_list.map do |job_id|
        end_point = [::SchedulerClientKeys['end_point'], group_name, job_id].join('/')
        scheduler_client = SchedulerService::Client.new(
          job_id: job_id,
          group: group_name,
          end_point: end_point,
          scheduler_type: "delete_scheduler_message_#{job_id}"
        )
        response = scheduler_client.cancel_job
        Rails.logger.info "scheduler response message successful deletion job_id:::: #{job_id} :::: #{response} :::: #{response.headers[:x_request_id]}"
        response
      end
    end
  end
end
