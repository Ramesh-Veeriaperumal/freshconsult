class Import::ContactWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :contact_import, :retry => 0, :backtrace => true,
                  :failures => :exhausted

  class SpamAccountError < StandardError
  end

  def perform(args)
    args.symbolize_keys!
    acc = Account.current
    if (
      acc.subscription.trial? and
      acc.tickets.count < 10 and
      !$spam_watcher.perform_redis_op("get", "#{acc.id}-")
    )
      raise SpamAccountError
    end
    Import::Customers::Contact.new(args).import
  end
end
