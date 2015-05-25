require 'twitter'
module Social

  class CustomTwitterWorker < BaseWorker  
    
    sidekiq_options :queue => :custom_twitter, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(msg = {})
        Social::CustomStreamTwitter.new(msg)
      ensure
        Account.reset_current_account
    end
    
   end

end
