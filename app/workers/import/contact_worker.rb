class Import::ContactWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :contact_import, :retry => 0, :backtrace => true,
                  :failures => :exhausted

  class SpamAccountError < StandardError
  end

  def perform(args)
    args.symbolize_keys!
    acc = Account.current
    if (acc.subscription.trial? and acc.tickets.count < 10 and !$spam_watcher.perform_redis_op("get", "#{acc.id}-"))
      acc.contact_imports.find(args[:data_import]).blocked!
      raise SpamAccountError
    end
    register_signal_handlers
    Import::Customers::Contact.new(args).import
  end

  private

    def register_signal_handlers
      trap('TERM') { 
        p "Inside TERM. Contact import killed."
        exit
      }
      trap('INT')  { 
        p "Inside INT. Contact import killed."
        exit
      }
      trap('QUIT') { 
        p "Inside QUIT. Contact import killed."
        exit
      }
    rescue => e
      p "Error in signal handlers"
    end
end
