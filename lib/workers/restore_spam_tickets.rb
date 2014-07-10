class Workers::RestoreSpamTickets
  extend Resque::AroundPerform   
  
  @queue = 'restore_spam_tickets_worker'

  def self.perform(args)
      account = Account.current
      users = account.users.with_conditions( ["id in (?) and deleted_at IS NOT NULL",args[:user_ids] ] )
      users.each do |user|
        Helpdesk::Ticket.spam_created_in(user).update_all( { :spam => false }, 
          ["helpdesk_tickets.account_id = ?",account.id] )
        user.deleted_at= nil
        user.send(:update_without_callbacks)
      end
    rescue Exception => e
      puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
    rescue
      puts "something went wrong"
  end
  
end