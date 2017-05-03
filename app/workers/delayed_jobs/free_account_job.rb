module DelayedJobs
  class FreeAccountJob < BaseWorker
    sidekiq_options :queue => :free_account_jobs, :retry => 25, :backtrace => false, :failures => :exhausted

    sidekiq_retry_in do |count|
      reschedule_timespan = (count ** 4) + 5
      reschedule_timespan = 4.hours if (reschedule_timespan > 4.hours) 
    end

    def perform(args)
      Rails.logger.info "Inside the sidekiq worker with id #{jid}. Processing job #{args['job_id']}."
      job = Free::Job.find_by_id(args["job_id"])
      if job
        job.run_without_lock(args["account_id"])
      else
        Rails.logger.error "Unable to fetch job #{args['job_id']} inside the worker #{jid}. Account id: #{args["account_id"]}"
      end    
    end
  end
end
