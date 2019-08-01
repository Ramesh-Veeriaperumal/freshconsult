module CronWebhooks::CronHelper
  include CronWebhooks::Constants

  def get_semaphore_key(options, misc = '')
    task = options[:task_name]
    misc = "#{options[:type]}:#{misc}"

    format(CRON_JOB_SEMAPHORE, task: task, misc: misc)
  end

  def dry_run_mode?(mode = nil)
    mode == DRYRUN
  end
end
