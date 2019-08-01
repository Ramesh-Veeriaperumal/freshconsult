module DelayedJobsWatcherConfig
  config = Rails.root.join('config', 'delayed_job_watcher.yml')

  DELAYED_JOB_QUEUES = (YAML.load_file config)[Rails.env]
  DELAYED_JOBS_MSG = "Queue's jobs needs your attention!".freeze
  PAGER_DUTY_FREQUENCY_SECS = Rails.env.production? ? 18_000 : 900 # 5 hours : # 15 mins
end
