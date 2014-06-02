module Admin
  class FreeSlaWorker < Admin::SlaWorker
    sidekiq_options :queue => :free_sla, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end