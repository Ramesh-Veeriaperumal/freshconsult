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

  class FreeNoteWorker < CentralPublisher::Worker
    sidekiq_options :queue => "free_note_central_publish", :retry => 5, :dead => true, :backtrace => true, :failures => :exhausted
  end

  class TrialNoteWorker < CentralPublisher::Worker
    sidekiq_options :queue => "trial_note_central_publish", :retry => 5, :dead => true, :backtrace => true, :failures => :exhausted
  end

  class ActiveNoteWorker < CentralPublisher::Worker
    sidekiq_options :queue => "active_note_central_publish", :retry => 5, :dead => true, :backtrace => true, :failures => :exhausted
  end

  class SuspendedNoteWorker < CentralPublisher::Worker
    sidekiq_options :queue => "suspended_note_central_publish", :retry => 5, :dead => true, :backtrace => true, :failures => :exhausted
  end

  class AccountWorker < CentralPublisher::Worker  
    def model_object
       @args[:event] == "delete" ? nil : Account.find(@args[:model_id])
    end
    
    def model_name
      'Account'
    end
    sidekiq_options :queue => "central_publish", :retry => 5, :dead => true, :backtrace => true, :failures => :exhausted
  end

  class UserWorker < CentralPublisher::Worker
    sidekiq_options :queue => "user_central_publish", :retry => 5, :dead => true, :failures => :exhausted
  end

  class TicketFieldWorker < CentralPublisher::Worker
    sidekiq_options :queue => "ticket_field_central_publish", :retry => 5, :dead => true, :failures => :exhausted
  end
  
  class CompanyWorker < CentralPublisher::Worker
    sidekiq_options :queue => "company_central_publish", :retry => 5, :dead => true, :backtrace => true, :failures => :exhausted
  end

  class SurveyWorker < CentralPublisher::Worker
    sidekiq_options queue: 'surveys_central_publish', retry: 5, dead: true, failures: :exhausted
  end

  class ContactFieldWorker < CentralPublisher::Worker
    sidekiq_options queue: 'contact_field_central_publish', retry: 5, dead: true, failures: :exhausted
  end

  class CompanyFieldWorker < CentralPublisher::Worker
    sidekiq_options queue: 'company_field_central_publish', retry: 5, dead: true, failures: :exhausted
  end

  class FreshcallerAccountWorker < CentralPublisher::Worker
    sidekiq_options queue: 'freshcaller_account_central_publish', retry: 5, dead: true, failures: :exhausted
  end

  class FreshchatAccountWorker < CentralPublisher::Worker
    sidekiq_options queue: 'freshchat_account_central_publish', retry: 5, dead: true, failures: :exhausted
  end
end
