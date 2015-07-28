class Workers::MergeTickets
  extend Resque::AroundPerform 
  
  @queue = 'merge_ticket_worker'
  STATES_TO_BE_MOVED = ["first_response_time", "requester_responded_at", "agent_responded_at"]
  TICKET_STATE_COLLECTION = {}

  def self.perform(args)
    current_account = Account.current
    user = current_account.users.find(args[:current_user_id])
    user.make_current
    source_tickets = current_account.tickets.find(:all, :conditions => { :display_id => args[:source_ticket_ids] })
    target_ticket = current_account.tickets.find(args[:target_ticket_id])
    source_ticket_note_ids = []
    
    activities_to_be_discarded = ["activities.tickets.new_ticket.long", "activities.tickets.status_change.long"]
    source_tickets.each do |source_ticket|
      source_ticket_note_ids << source_ticket.notes.map(&:id)
      source_ticket.notes.update_all( "notable_id = #{args[:target_ticket_id]}", [ "account_id = ?", 
                                                                                args[:account_id] ] )
      source_ticket.activities.update_all("notable_id = #{args[:target_ticket_id]}", [ "account_id = ? and description NOT IN (?)", 
                                                                                args[:account_id], activities_to_be_discarded ] )
      source_ticket.time_sheets.update_all("workable_id = #{args[:target_ticket_id]}", [ "account_id = ?", 
                                                                                args[:account_id] ] )
      STATES_TO_BE_MOVED.each do |state|
        TICKET_STATE_COLLECTION[state] = (TICKET_STATE_COLLECTION[state] || []).push(source_ticket.send(state))
      end
      add_note_to_source_ticket(source_ticket, args[:source_note_private], args[:source_note])
      update_merge_activity(source_ticket,target_ticket)
    end
    update_target_ticket_states(target_ticket)
    # notes are added to the target ticket via update_all. This wont trigger callback
    # So sending it manually
    update_target_ticket_notes_to_reports(target_ticket, source_ticket_note_ids.flatten)
  end

  def self.add_note_to_source_ticket(source_ticket, source_note_private, source_info_note)
    pvt_note = source_ticket.requester_has_email? ? source_note_private : true
    source_note = source_ticket.notes.build(
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
    source_note.save_note
  end

  def self.update_target_ticket_states(target_ticket)
    STATES_TO_BE_MOVED.each do |state| 
      current_state_collection = TICKET_STATE_COLLECTION[state].push(target_ticket.send(state))
      operator = ( state == 'first_response_time' ? 'min' : 'max' )
      target_ticket.ticket_states.send("#{state}=",current_state_collection.compact.send(operator))
    end
    target_ticket.ticket_states.set_avg_response_time
    if target_ticket.ticket_states.first_response_time_changed?
      BusinessCalendar.execute(target_ticket) {
        business_calendar_config = Group.default_business_calendar(target_ticket.group)
        target_ticket.ticket_states.first_resp_time_by_bhrs = Time.zone.parse(target_ticket.created_at.to_s).
          business_time_until(Time.zone.parse(target_ticket.ticket_states.first_response_time.to_s),business_calendar_config)
      }
    end
    target_ticket.ticket_states.save
  end

  def self.update_merge_activity(source_ticket,target_ticket)
    source_ticket.create_activity(User.current, 'activities.tickets.ticket_merge.long',
          {'eval_args' => {'merge_ticket_path' => ['merge_ticket_path', 
          {'ticket_id' => target_ticket.display_id, 'subject' => target_ticket.subject}]}}, 
                                'activities.tickets.ticket_merge.short') 
  end
    
  
  ##  **  Methods related to reports starts here **  ##
  # Here we are sending the target ticket notes to RMQ for reporting purpose
  # We are not sending the source ticket updates to RMQ because source ticket(which is closed) should 
  # not be included in any of the reporting metrics. So not sending any updates for the source ticket.
  def self.update_target_ticket_notes_to_reports(target_ticket, note_ids)
    # TODO Must send only one push for all the subscribers(reports, search, activities)
    # Currently only reports is handled.
    # Need to handle it in a generic way for all the subscribers
    target_ticket_notes = target_ticket.notes.where({:id => note_ids})
    target_ticket_notes.each do |note|
      next unless note.send(:human_note_for_ticket?)
      category = note.send(:reports_note_category)
      next unless Helpdesk::SchemaLessTicket::COUNT_COLUMNS_FOR_REPORTS.include?(category)
      note.notable.schema_less_ticket.send("update_#{category}_count", "create")
      note.notable.schema_less_ticket.save
      note.manual_publish_to_rmq("create", RabbitMq::Constants::RMQ_REPORTS_NOTE_KEY)
    end
    # while doing manual publish of note it will take note's created at and hence it will not be
    # reflected in latest row. Doing a manual push for target ticket here so that the latest row of the ticket will 
    # have all the customer reply and agent reply count updated.
    target_ticket.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_REPORTS_TICKET_KEY, {:manual_publish => true})
  end
end
