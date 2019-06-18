module Admin
  class PremiumSupervisorWorker  < Admin::SupervisorWorker
    
    sidekiq_options :queue => :premium_supervisor, :retry => 0, :failures => :exhausted
  end
end