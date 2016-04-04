require 'active_record_shards'

module Trial
  class Job < Delayed::Job
    self.table_name =  :trial_account_jobs
  end
end
