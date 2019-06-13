module AccountCreation

  class PopulateSeedData < BaseWorker

    sidekiq_options :queue => :account_creation_fixtures, :retry => 5, :failures => :exhausted
    sidekiq_retry_in { 30 }


    sidekiq_retries_exhausted do |msg, e|
      Account.current.set_background_fixtures_failed
      Sidekiq.logger.warn "Failed #{msg['class']} with #{msg['args']}: #{msg['error_message']}"
    end
    

    def perform(args={})
      begin
        account = Account.current
        account.set_background_fixtures_started
        ActiveRecord::Base.transaction do
          SeedFu::PopulateSeed.populate_background
        end
        account.background_fixtures_completed
      rescue Exception => e
        account.set_background_fixtures_awaiting_retry
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
        raise e
      end
    end
  end
end
