class Tickets::RestoreSpamTickets
  include Sidekiq::Worker

  sidekiq_options :queue => :restore_spam_tickets, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
  	account = Account.current
    users = account.users.where(:id => args[:user_ids] )
    users.each do |user|
      Helpdesk::Ticket.spam_created_in(user)
      .where(["helpdesk_tickets.account_id = ?",account.id])
      .update_all_with_publish({ :spam => false }, {}, {:reason => {:spam => [true, false]}, :manual_publish => true})

      user.class.where(:id => user.id, :account_id => user.account_id)
      .update_all_with_publish({ :deleted_at => nil }, 'deleted_at is not null')
    end
  rescue Exception => e
    puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
    NewRelic::Agent.notice_error(e, {:custom_params => {:description => "Error occoured while restoring spam tickets"}})
  end
end