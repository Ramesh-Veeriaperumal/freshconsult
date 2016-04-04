module Social
  class TrialFacebookWorker < Social::FacebookWorker
    
    
    sidekiq_options :queue => :trial_facebook, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end
