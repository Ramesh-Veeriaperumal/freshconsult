require 'active_record_shards'

module Premium
  class Job < Delayed::Job
    self.table_name =  :premium_account_jobs
  end
end
