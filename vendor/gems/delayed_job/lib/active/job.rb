require 'active_record_shards'

module Active
  class Job < Delayed::Job
    self.table_name =  :active_account_jobs
  end
end
