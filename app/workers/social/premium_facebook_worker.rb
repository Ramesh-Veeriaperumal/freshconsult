module Social
  class PremiumFacebookWorker < Social::FacebookWorker
    
    
    sidekiq_options :queue => :premium_facebook, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end