class Tickets::RestoreSpamTicketsWorker
  include Sidekiq::Worker

  sidekiq_options :queue => :restore_spam_tickets, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
  	account = Account.current
    users = account.users.where(:id => args[:user_ids] )
    users.each do |user|
      ticket_ids = []
      account.tickets.spam_created_in(user).where(account_id: account.id).find_each do |ticket|
        ticket_ids << ticket.id
      end if account.omni_channel_routing_enabled?

      Helpdesk::Ticket.spam_created_in(user)
      .where(["helpdesk_tickets.account_id = ?",account.id])
      .update_all_with_publish({ :spam => false }, {}, {:reason => {:spam => [true, false]}, :manual_publish => true})

      account.tickets.where(id: ticket_ids).find_each do |ticket|
        ticket.sync_task_changes_to_ocr(active: [false, true]) if ticket.eligible_for_ocr?
      end if ticket_ids.present?

      user.class.where(:id => user.id, :account_id => user.account_id)
      .update_all_with_publish({ :deleted_at => nil }, 'deleted_at is not null')
    end
  rescue Exception => e
    puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
    NewRelic::Agent.notice_error(e, {:custom_params => {:description => "Error occoured while restoring spam tickets"}})
  end
end
