class Workers::Import::Contact
  extend Resque::AroundPerform

  @queue = "contact_import"

  def self.perform(args)
    acc = Account.find_by_id(args[:account_id])
    if acc.subscription.trial? and acc.tickets.count < 10 and !$spam_watcher.perform_redis_op("get", "#{acc.id}-")
      acc.contact_import.blocked!
      raise "Spam Account"
    end
    Import::Customers::Contact.new(args).import
  end
  
end