module Archive
  class DeleteTicketDependencies < BaseWorker
    sidekiq_options :queue => :archive_delete_ticket_dependencies, :retry => 0, :backtrace => true, :failures => :exhausted
    
    def perform(args)
      begin
        Archive::Core::Base.new.mysql_ticket_delete(args["ticket_id"],args["account_id"])     
      ensure
        Account.reset_current_account
      end
    end
  end
end
