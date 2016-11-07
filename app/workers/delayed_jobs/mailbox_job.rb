module DelayedJobs
  class MailboxJob < BaseWorker
    sidekiq_options :queue => :mailbox_jobs, :retry => 25, :backtrace => false, :failures => :exhausted

    sidekiq_retry_in do |count|
      reschedule_timespan = (count ** 4) + 5
      reschedule_timespan = 4.hours if (reschedule_timespan > 4.hours) 
    end

    def perform(args)
      job = Mailbox::Job.find_by_id(args["job_id"])
      job.run_without_lock if job
    end
  end
end
