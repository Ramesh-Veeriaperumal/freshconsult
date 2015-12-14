class Workers::Import::Contact
  extend Resque::AroundPerform

  @queue = "contact_import"

  def self.perform(args)
  	acc = Account.find(args[:account_id])
  	raise "Spam Account" if acc.subscription.trial? and acc.tickets.count < 10 and !$spam_watcher.get(acc.id)
    Import::Customers::Contact.new(args).import
  end
  
end