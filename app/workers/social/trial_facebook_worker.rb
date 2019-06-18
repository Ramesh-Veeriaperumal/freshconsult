module Social
  class TrialFacebookWorker < Social::FacebookWorker
    
    
    sidekiq_options :queue => :trial_facebook, :retry => 0, :failures => :exhausted
  end
end
