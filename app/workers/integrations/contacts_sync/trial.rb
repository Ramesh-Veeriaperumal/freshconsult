module Integrations::ContactsSync
  class Trial < Integrations::ContactsSync::Base
  	sidekiq_options :queue => :contacts_sync_trial, :retry => 0, :backtrace => true, :failures => :exhausted

  end
end
