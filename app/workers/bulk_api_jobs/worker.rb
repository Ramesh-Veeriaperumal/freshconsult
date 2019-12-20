module BulkApiJobs
  class Worker < BaseWorker
    include BulkApiJobsHelper

    def perform(args)
      args.symbolize_keys!
      account = Account.current
      job = pick_job(args[:request_id])
      update_job(args[:request_id], 'status_id' => BULK_API_JOB_STATUSES['IN_PROGRESS'])
      payload = job.item['payload']
      partial = false

      payload, partial = safe_send('process_payload', account, payload, partial)

      status = partial ? BULK_API_JOB_STATUSES['PARTIAL'] : BULK_API_JOB_STATUSES['SUCCESS']
      update_job(args[:request_id], {'status_id' => status, 'payload' => payload})
    rescue Exception => e
      Rails.logger.debug "Failed to bulk update : #{e.class} #{e.message}"
      update_job(args[:request_id], {'status_id' => BULK_API_JOB_STATUSES['FAILED']})
      NewRelic::Agent.notice_error(e, {:args => args})
    end
  end
end
