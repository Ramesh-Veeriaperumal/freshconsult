module BulkApiJobs
  class Worker < BaseWorker
    include BulkApiJobsHelper

    def perform(args)
      args.symbolize_keys!
      item = pick_job(args[:request_id])
      update_job(args[:request_id], 'status_id' => BULK_API_JOB_STATUSES['IN_PROGRESS'])
      payload = item['payload']
      if item['current_user_id'].present?
        user = Account.current.technicians.find_by_id(item['current_user_id'])
        if user.present?
          user.make_current
        else
          Rails.logger.debug "User not found : #{item['current_user_id']}"
        end
      end
      succeeded = 0

      payload, succeeded = safe_send("process_#{item['action']}_payload", payload, succeeded)

      status = case succeeded
               when 0
                 BULK_API_JOB_STATUSES['FAILED']
               when payload.count
                 BULK_API_JOB_STATUSES['SUCCESS']
               else
                 BULK_API_JOB_STATUSES['PARTIAL']
               end
      update_job(args[:request_id], {'status_id' => status, 'payload' => payload})
    rescue Exception => e
      Rails.logger.debug "Failed to perform bulk operation : #{e.class} #{e.message} #{e.backtrace}"
      update_job(args[:request_id], {'status_id' => BULK_API_JOB_STATUSES['FAILED']})
      NewRelic::Agent.notice_error(e, {:args => args})
    end
  end
end
