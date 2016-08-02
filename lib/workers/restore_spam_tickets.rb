class Workers::RestoreSpamTickets
  extend Resque::AroundPerform   
  
  @queue = 'restore_spam_tickets_worker'

  def self.perform(args)
    account = Account.current
    users = account.users.with_conditions( ["id in (?) and deleted_at IS NOT NULL",args[:user_ids] ] )
    users.each do |user|
      Helpdesk::Ticket.spam_created_in(user)
      .where(["helpdesk_tickets.account_id = ?",account.id])
      .update_all_with_publish({ :spam => false }, {})

      user.class.where(:id => user.id, :account_id => user.account_id)
      .update_all_with_publish({ :deleted_at => nil }, 'deleted_at is not null')
    end
  rescue Exception => e
    puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
  end
end
