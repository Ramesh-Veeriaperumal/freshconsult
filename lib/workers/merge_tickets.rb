class Workers::MergeTickets
  extend Resque::AroundPerform 
  @queue = 'merge_ticket_worker'

  def self.perform(args)
    source_tickets = Helpdesk::Ticket.find(:all, :conditions => { :display_id => args[:source_ticket_ids], 
                                                                  :account_id => args[:account_id] })
    source_tickets.each do |source_ticket|
      source_ticket.notes.update_all( "notable_id = #{args[:target_ticket_id]}", [ "account_id = ?", 
                                                                                args[:account_id] ] )
      add_note_to_source_ticket(source_ticket, args[:source_note_private], args[:source_note])
    end
  end

  def self.before_perform_set_current_user(*args)
    params_hash = args[0].symbolize_keys!
    user = User.find_by_account_id_and_id(params_hash[:account_id], params_hash[:current_user_id])
    user.make_current
  end

  def self.add_note_to_source_ticket(source_ticket, source_note_private, source_info_note)
    pvt_note = source_ticket.requester_has_email? ? source_note_private : true
    source_note = source_ticket.notes.create(
      :body_html => source_info_note,
      :private => pvt_note || false,
      :source => pvt_note ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] : 
      										Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
      :account_id => Account.current.id,
      :user_id => User.current && User.current.id,
      :from_email => source_ticket.reply_email,
      :to_emails => pvt_note ? [] : source_ticket.requester.email.to_a,
      :cc_emails => pvt_note ? [] : source_ticket.cc_email_hash && source_ticket.cc_email_hash[:cc_emails]
    )
    if !source_note.private
      Helpdesk::TicketNotifier.send_later(:deliver_reply, source_ticket, source_note , 
                                                                        {:include_cc => true})
    end
  end
end
