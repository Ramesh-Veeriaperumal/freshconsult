module TicketsMergeTestHelper

  def sample_merge_request_params(target_ticket_id, source_ticket_ids)
    {
      primary_id: target_ticket_id,
      ticket_ids: source_ticket_ids,
      note_in_primary: {
        body: Faker::Lorem.paragraph,
        private: true
      },
      note_in_secondary: {
        body: Faker::Lorem.paragraph,
        private: true
      }
    }
  end

  def merge_error_pattern(errors)
    {
      description: "Validation failed",
      errors: errors
    }
  end

  def merge_attribute_missing_pattern
    attrs = [:primary_id, :ticket_ids, :note_in_primary, :note_in_secondary]
    errors = attrs.map do |attrb|
      {
        field: attrb,
        message: 'Mandatory attribute missing',
        code: 'missing_field'
      }
    end
    merge_error_pattern(errors)
  end

  def merge_invalid_field_pattern
    error = {
      field: 'invalid_field',
      message: 'Unexpected/invalid field in request',
      code: 'invalid_field'
    }
    merge_error_pattern([error])
  end

  def merge_invalid_ids_pattern(ids)
    merge_error_pattern([{ field: 'ticket_ids', message: "There are no records matching the ids: '#{ids.join(', ')}'", code: 'invalid_value' }])
  end

  def merge_imperssible_ids_pattern(ids)
    merge_error_pattern([{ field: 'ticket_ids', message: "Permission denied for records with ids : '#{ids.join(', ')}'.", code: 'invalid_value' }])
  end

  def merge_assoc_tkt_pattern(ids)
    merge_error_pattern([{ field: 'ticket_ids', message: "cant merge an associated tickets for records with ids : '#{ids.join(', ')}'", code: 'invalid_value' }])
  end

  def merge_imperssible_invalid_pattern(imperssible_ids, invalid_ids)
    merge_error_pattern([{ 
      field: 'ticket_ids',
      message: "There are no records matching the ids: '#{invalid_ids.join(', ')}'. Permission denied for records with ids : '#{imperssible_ids.join(', ')}'.",
      code: 'invalid_value' 
    }])
  end

  def add_reply_cc_emails_to_ticket(tickets, range = 40..50)
    tickets.each do |ticket| 
      fake_emails = rand(range).times.inject([]) { |arr, id| arr << Faker::Internet.email }
      ticket.cc_email[:reply_cc] = fake_emails
      ticket.save
    end
  end

  def add_forwarded_emails(tickets, range = 2..5)
    tickets.each do |ticket|
      fake_emails = rand(range).times.inject([]) { |arr, id| arr << Faker::Internet.email }
      ticket.cc_email[:fwd_emails] = fake_emails
      ticket.save
    end
  end

  def merge_reply_cc_error_pattern
    merge_error_pattern([{ field: 'convert_recepients_to_cc', message: 'Has exceeded maximum limit', code: "invalid_value" }])
  end

  def merge_incompletion_pattern
    merge_error_pattern([{ field: 'merge', message: 'Unable to to complete the merge.', code: 'invalid_value' }])
  end

  def add_timesheets_to_ticket(tickets)
    tickets.each do |ticket|
      time_sheet = FactoryGirl.build(:time_sheet, user_id: @agent.id, workable_id: ticket.id, account_id: @account.id, billable: 1, note: '')
      time_sheet.save
    end
  end

  def validate_merge_action(target, source_tickets, check_timesheet = true)
    target.reload
    # check status as closed for source tickets
    source_reply_ccs = []
    source_forwarded_emails = []
    source_tickets.each do |ticket|
      ticket.reload
      assert ticket.parent_ticket == target.id
      assert ticket.status == Helpdesk::Ticketfields::TicketStatus::CLOSED
      source_reply_ccs << ticket.cc_email[:reply_cc]
      source_forwarded_emails << ticket.cc_email[:fwd_emails]
    end
    # check for combined cc emails in target
    source_reply_ccs.flatten.each do |email|
      assert target.cc_email[:reply_cc].include?(email)
    end

    source_forwarded_emails.flatten.each do |email|
      assert target.cc_email[:fwd_emails].include?(email)
    end

    # check for the added note target
    all_target_notes = target.notes
    source_tickets.each do |ticket|
      flag = false
      all_target_notes.each do |note|
        if note.body_html.include?(ticket.display_id.to_s) && note.body_html.include?(ticket.subject) && note.body_html.include?(ticket.description_html)
          flag = true
        end
      end
      assert flag
    end

    if check_timesheet
      # checking the timesheets
      source_tickets.each do |ticket|
        refute @account.time_sheets.where(workable_type: 'Helpdesk::Ticket', workable_id: ticket.id).present?
      end

      assert @account.time_sheets.where(workable_type: 'Helpdesk::Ticket', workable_id: target.id).present?
      assert @account.time_sheets.where(workable_type: 'Helpdesk::Ticket', workable_id: target.id).count == source_tickets.count
    end
  end

end
