module Integrations::ContactsSync
  class Paid < Integrations::ContactsSync::Base
  	sidekiq_options :queue => :contacts_sync_paid, :retry => 0, :backtrace => true, :failures => :exhausted

  end
end
