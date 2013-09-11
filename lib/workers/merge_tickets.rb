class Workers::MergeTickets
  extend Resque::AroundPerform 
  @queue = 'merge_ticket_worker'

  def self.perform(args)
    user = User.find_by_account_id_and_id(args[:account_id], args[:current_user_id])
    user.make_current
    source_tickets = Helpdesk::Ticket.find(:all, :conditions => { :display_id => args[:source_ticket_ids], 
                                                                  :account_id => args[:account_id] })
    source_tickets.each do |source_ticket|
      source_ticket.notes.update_all( "notable_id = #{args[:target_ticket_id]}", [ "account_id = ?", 
                                                                                args[:account_id] ] )
      add_note_to_source_ticket(source_ticket, args[:source_note_private], args[:source_note])
    end
  end

  def self.add_note_to_source_ticket(source_ticket, source_note_private, source_info_note)
    pvt_note = source_ticket.requester_has_email? ? source_note_private : true
    source_note = source_ticket.notes.create(
      :note_body_attributes => {:body_html => source_info_note},
      :private => pvt_note || false,
      :source => pvt_note ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] : 
      										Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
      :account_id => Account.current.id,
      :user_id => User.current && User.current.id,
      :from_email => source_ticket.reply_email,
      :to_emails => pvt_note ? [] : source_ticket.requester.email.to_a,
      :cc_emails => pvt_note ? [] : source_ticket.cc_email_hash && source_ticket.cc_email_hash[:cc_emails]
    )
  end
end
