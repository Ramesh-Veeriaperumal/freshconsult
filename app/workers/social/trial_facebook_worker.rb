module Social
  class TrialFacebookWorker < Social::FacebookWorker
    
    
    sidekiq_options :queue => :trail_facebook, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end
