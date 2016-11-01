module Integrations::ContactsSync
  class Free < Integrations::ContactsSync::Base
  	sidekiq_options :queue => :contacts_sync_free, :retry => 0, :backtrace => true, :failures => :exhausted

  end
end
