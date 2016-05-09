require 'active_record_shards'

module Mailbox
  class Job < Delayed::Job
    self.table_name =  :mailbox_jobs
    MAX_RUN_TIME = 5.minutes
  end
end
