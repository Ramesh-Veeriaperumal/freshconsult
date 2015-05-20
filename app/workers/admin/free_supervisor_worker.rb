module Admin
  class FreeSupervisorWorker < Admin::SupervisorWorker
    
    sidekiq_options :queue => :free_supervisor, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end