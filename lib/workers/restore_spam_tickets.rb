class Workers::RestoreSpamTickets
  extend Resque::Plugins::Retry  
  @retry_limit = 3

  @retry_delay = 60*2
  @queue = 'restore_spam_tickets_worker'

  def self.perform(account_id,user_ids)
    begin
      account =  Account.find(account_id)
      account.make_current
      users = account.users.with_conditions(["id in (?) and deleted_at IS NOT NULL",user_ids])
      users.each do |user|
        Helpdesk::Ticket.spam_created_in(user).update_all( { :spam => false }, 
          ["helpdesk_tickets.account_id = ?",account_id] )
        user.deleted_at= nil
        user.send(:update_without_callbacks)
      end
    rescue Exception => e
      puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
    rescue
      puts "something went wrong"
    end
    Account.reset_current_account 
  end
end