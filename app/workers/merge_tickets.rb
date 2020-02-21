class MergeTickets < BaseWorker
  sidekiq_options :queue => :merge_tickets, :retry => 0, :failures => :exhausted
  STATES_TO_BE_MOVED = ["first_response_time", "requester_responded_at", "agent_responded_at"]
  ACTIVITIES_TO_BE_DISCARDED = ["activities.tickets.new_ticket.long", "activities.tickets.status_change.long"]

  def perform(args)
    args.symbolize_keys!
    account = Account.current
    tkt_states_hash = {}
    source_tickets = account.tickets.where(:display_id => args[:source_ticket_ids] )
    target_ticket = account.tickets.find(args[:target_ticket_id])
    source_ticket_note_ids = []
    set_locale
    source_tickets.each do |source_ticket|
      delete_ticket_summary(source_ticket)
      move_source_time_sheets_to_target(source_ticket,args[:target_ticket_id])
      move_source_description_to_target(source_ticket,target_ticket,args[:target_note_private])
      source_ticket_note_ids << source_ticket.notes.pluck(:id)
      source_ticket.notes.update_all_with_publish({ notable_id: args[:target_ticket_id] },
                                    [ "account_id = ? and notable_id != ?", account.id, args[:target_ticket_id] ])
      source_ticket.activities.update_all("notable_id = #{args[:target_ticket_id]}", [ "account_id = ? and description NOT IN (?)", 
                                                                                account.id, ACTIVITIES_TO_BE_DISCARDED ] )
      source_ticket.time_sheets.update_all("workable_id = #{args[:target_ticket_id]}", [ "account_id = ?", 
                                                                                account.id ] )
      STATES_TO_BE_MOVED.each do |state|
        tkt_states_hash[state] = (tkt_states_hash[state] || []).push(source_ticket.safe_send(state))
      end
      add_note_to_source_ticket(source_ticket, args[:source_note_private], args[:source_note])
      remove_ecommerce_mapping(source_ticket) if source_ticket.ecommerce?
      update_merge_activity(source_ticket,target_ticket)
    end
    update_target_ticket_states(target_ticket, tkt_states_hash)
    # notes are added to the target ticket via update_all. This wont trigger callback
    # So sending it manually
    update_target_ticket_notes_to_subscribers(target_ticket, source_ticket_note_ids.flatten, args[:source_ticket_ids])
  ensure
    I18n.locale = I18n.default_locale
  end

  def delete_ticket_summary(source_ticket)
    source_ticket.summary.destroy if source_ticket.summary
  end


  def add_note_to_source_ticket(source_ticket, source_note_private, source_info_note)
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

  def update_target_ticket_states(target_ticket, tkt_states_hash)
    STATES_TO_BE_MOVED.each do |state| 
      current_state_collection = tkt_states_hash[state].push(target_ticket.safe_send(state))
      operator = ( state == 'first_response_time' ? 'min' : 'max' )
      target_ticket.ticket_states.safe_send("#{state}=",current_state_collection.compact.safe_send(operator))
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

  def update_merge_activity(source_ticket,target_ticket)
    source_ticket.create_activity(User.current, 'activities.tickets.ticket_merge.long',
          {'eval_args' => {'merge_ticket_path' => ['merge_ticket_path', 
          {'ticket_id' => target_ticket.display_id, 'subject' => target_ticket.subject}]}}, 
                                'activities.tickets.ticket_merge.short') 
  end

  def remove_ecommerce_mapping(source_ticket)
     if source_ticket.ebay_question.present?
        Ecommerce::EbayQuestion.where(:account_id => source_ticket.account_id,
          :questionable_id => source_ticket.id, :questionable_type => source_ticket.class.name ).update_all({:questionable_id => nil, :questionable_type => nil})
     end
  end
  
  ##  **  Methods related to subscribers starts here **  ##
  # REPORTS: Here we are sending the target ticket notes to RMQ for reporting purpose
  # We are not sending the source ticket updates to RMQ because source ticket(which is closed) should 
  # not be included in any of the reporting metrics. So not sending any updates for the source ticket.
  def update_target_ticket_notes_to_subscribers(target_ticket, note_ids, source_ticket_ids)
    # Currently reports and Activities are handled.
    # Need to append RMQ_GENERIC_NOTE_KEY to enable for other subscribers
    target_ticket_notes = target_ticket.notes.where({:id => note_ids})
    target_ticket_notes.each do |note|
      next unless note.safe_send(:human_note_for_ticket?)
      category = note.safe_send(:reports_note_category)
      next unless Helpdesk::SchemaLessTicket::COUNT_COLUMNS_FOR_REPORTS.include?(category)
      note.notable.schema_less_ticket.safe_send("update_#{category}_count", "create")
      note.notable.schema_less_ticket.save
      note.manual_publish(["create", RabbitMq::Constants::RMQ_REPORTS_NOTE_KEY], [])
    end
    # ACTIVTIIES: Adding ticket merge activity in target ticket
    target_ticket.activity_type = {:type => "ticket_merge_target", 
      :source_ticket_id => source_ticket_ids, 
      :target_ticket_id => [target_ticket.display_id]}
    # REPORTS: while doing manual publish of note it will take note's created at and hence it will not be
    # reflected in latest row. Doing a manual push for target ticket here so that the latest row of the ticket will 
    # have all the customer reply and agent reply count updated.
    key  = RabbitMq::Constants::RMQ_CLEANUP_TICKET_KEY
    target_ticket.manual_publish(["update", key, {:manual_publish => true}], [:update, { misc_changes: target_ticket.activity_type.dup }])
  end

  def move_source_time_sheets_to_target(source_ticket,target_ticket_id)
    source_ticket.time_sheets.each do |time_sheet|
      time_sheet.update_attribute(:workable_id, target_ticket_id)
    end
  end

  def move_source_description_to_target(source_ticket,target_ticket,target_note_private)
    source_description_note = target_ticket.notes.build(
      :note_body_attributes => {:body_html => build_source_description_body_html(source_ticket)},
      :private => target_note_private || false,
      :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
      :account_id => Account.current.id,
      :user_id => User.current && User.current.id
    )
    source_description_note.save_note
    MergeTicketsAttachments.perform_async({ :source_ticket_id => source_ticket.id,
                                            :target_ticket_id => target_ticket.id, 
                                            :source_description_note_id => source_description_note.id })
  end

  def build_source_description_body_html source_ticket
    %{#{I18n.t('helpdesk.merge.bulk_merge.target_merge_description1', :ticket_id => source_ticket.display_id, 
                                                      :full_domain => source_ticket.portal.host)}<br/><br/>
      <b>#{I18n.t('Subject')}:</b> #{source_ticket.subject}<br/><br/>
      <b>#{I18n.t('description')}:</b><br/>#{source_ticket.description_html}}
  end

  def set_locale
    I18n.locale = User.current.try(:language) || I18n.default_locale
  end
end
