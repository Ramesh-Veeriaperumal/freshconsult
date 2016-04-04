require 'active_record_shards'

module Free
  class Job < Delayed::Job
    self.table_name =  :free_account_jobs
  end
end
