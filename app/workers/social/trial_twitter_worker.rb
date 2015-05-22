module Social
  class TrialTwitterWorker < Social::TwitterWorker
    
    
    sidekiq_options :queue => :trail_twitter, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end
