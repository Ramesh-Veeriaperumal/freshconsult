module Social
  class PremiumTwitterWorker < Social::TwitterWorker
    
    
    sidekiq_options :queue => :premium_twitter, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end