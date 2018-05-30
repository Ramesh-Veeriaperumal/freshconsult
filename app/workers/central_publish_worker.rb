module CentralPublishWorker
  class FreeTicketWorker < CentralPublisher::Worker
    sidekiq_options :queue => "free_ticket_central_publish", :retry => 5, :dead => true, :backtrace => true, :failures => :exhausted
  end

  class TrialTicketWorker < CentralPublisher::Worker
    sidekiq_options :queue => "trial_ticket_central_publish", :retry => 5, :dead => true, :backtrace => true, :failures => :exhausted
  end

  class ActiveTicketWorker < CentralPublisher::Worker
    sidekiq_options :queue => "active_ticket_central_publish", :retry => 5, :dead => true, :backtrace => true, :failures => :exhausted
  end

  class SuspendedTicketWorker < CentralPublisher::Worker
    sidekiq_options :queue => "suspended_ticket_central_publish", :retry => 5, :dead => true, :backtrace => true, :failures => :exhausted
  end

  class AccountDeletionWorker < CentralPublisher::Worker

    def model_object
      nil
    end

    def model_name
      'Account'
    end
    
  end

  class UserWorker < CentralPublisher::Worker
    sidekiq_options :queue => "user_central_publish", :retry => 5, :dead => true, :failures => :exhausted
  end
end
