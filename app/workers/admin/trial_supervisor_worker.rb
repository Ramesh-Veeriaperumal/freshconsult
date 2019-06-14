module Admin
  class TrialSupervisorWorker < Admin::SupervisorWorker
    
    sidekiq_options :queue => :trial_supervisor, :retry => 0, :failures => :exhausted
  end
end