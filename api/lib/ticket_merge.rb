class TicketMerge
  include Helpdesk::ToggleEmailNotification
  include ParserUtil
  include Redis::RedisKeys
  include Redis::OthersRedis

  attr_accessor :target, :source_tickets, :params, :convert_to_cc, :header, :target_reply_cc

  def initialize(target, source_tickets, params)
    @target = target
    @source_tickets = source_tickets
    @params = params
    @convert_to_cc = params[:convert_recepients_to_cc]
    @header = target.header_info || {}
    @target_reply_cc = get_reply_cc_email(target)
  end

  def perform
    update_source_tickets
    move_source_notes
    target.header_info = header unless header.blank?
    move_requesters if convert_to_cc
    target.save
    add_note_to_target
    true
  rescue => e
    options_hash =  { custom_params: { description: 'Ticket Merge Error', params: params } }
    NewRelic::Agent.notice_error(e, options_hash)
    false
  end

  private

    def update_source_tickets
      source_tickets.each do |source_ticket|
        move_time_sheets(source_ticket)
        move_description(source_ticket)
        # setting an attr accessor variable for activities
        source_ticket.activity_type = {
          type: 'ticket_merge_source',
          source_ticket_id: [source_ticket.display_id],
          target_ticket_id: [target.display_id]
        }
        close_source_ticket(source_ticket)
        update_header_info(source_ticket.header_info) if source_ticket.header_info
      end
    end

    def move_time_sheets(source_ticket)
      source_ticket.time_sheets.each do |time_sheet|
        time_sheet.update_attribute(:workable_id, target.id)
      end
    end

    def move_description(source_ticket)
      source_description_note = target.notes.build(description_note_attribs(source_ticket))
      source_description_note.save_note
      MergeTicketsAttachments.perform_async(
        source_ticket_id: source_ticket.id,
        target_ticket_id: target.id,
        source_description_note_id: source_description_note.id
      )
    end

    def description_note_attribs(source_ticket)
      {
        note_body_attributes: {
          body_html: source_description_body_html(source_ticket)
        },
        private: @params[:note_in_primary][:private] || false,
        source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
        account_id: Account.current.id,
        user_id: User.current.id
      }
    end

    def close_source_ticket(source_ticket)
      disable_notification(Account.current)
      source_ticket.parent_ticket = target.id
      source_ticket.update_attribute(:status, Helpdesk::Ticketfields::TicketStatus::CLOSED)
      enable_notification(Account.current)
    end

    def update_header_info(source_header)
      (source_header[:message_ids] || []).each do |source|
        update_source_header(source) unless header[:message_ids].include?(source)
      end
    end

    def update_source_header(source)
      (header[:message_ids] ||= []) << source
      source_key = EMAIL_TICKET_ID % { account_id: Account.current.id, message_id: source }
      set_others_redis_key(source_key, "#{target.display_id}:#{source}", 86_400 * 7)
    end

    def move_source_notes
      MergeTickets.perform_async(
        source_ticket_ids: source_tickets.map(&:display_id),
        target_ticket_id: target.id,
        source_note_private: @params[:note_in_secondary][:private] || false,
        source_note: @params[:note_in_secondary][:body]
      )
    end

    def move_requesters
      reply_cc_emails = all_emails_for_target
      cc_emails = get_email_array(reply_cc_emails)
      return unless cc_emails.any?
      add_requesters_to_target(reply_cc_emails, cc_emails)
    end

    def add_requesters_to_target(reply_cc_emails, cc_emails)
      emails_list = [reply_cc_emails, cc_emails]
      target.cc_email.blank? ? target_cc_email_attribs(*emails_list) : set_target_cc_emails(*emails_list)
    end

    def target_cc_email_attribs(reply_cc_emails, cc_emails)
      target.cc_email = {
        cc_emails: cc_emails,
        fwd_emails: [],
        reply_cc: reply_cc_emails,
        tkt_cc: []
      }
    end

    def set_target_cc_emails(reply_cc_emails, cc_emails)
      target.cc_email[:cc_emails] = get_cc_email(target).concat(cc_emails).uniq
      target.cc_email[:reply_cc] = target_reply_cc.concat(reply_cc_emails).first(TicketConstants::MAX_EMAIL_COUNT - 1)
    end

    def add_note_to_target
      target_note = target.notes.build(target_note_attributes)
      target_note.save_note
    end

    def target_note_attributes
      private_note = target.requester_has_email? ? @params[:note_in_primary][:private] : true
      {
        note_body_attributes: {
          body_html: @params[:note_in_primary][:body]
        },
        private: private_note,
        source: target_note_source(private_note),
        account_id: Account.current.id,
        user_id: User.current.id,
        from_email: target.reply_email,
        to_emails: target_note_emails(private_note),
        cc_emails: target_note_emails(private_note, :cc_emails)
      }
    end

    def target_note_source(is_private)
      is_private ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] : Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
    end

    def target_note_emails(is_private, type = :to_emails)
      return [] if is_private
      if type == :to_emails
        target.requester.email.lines.to_a
      else
        target.cc_email_hash && target.cc_email_hash[:cc_emails]
      end
    end

    def source_description_body_html(source_ticket)
      %(
        #{I18n.t(
          'helpdesk.merge.bulk_merge.target_merge_description1',
          ticket_id: source_ticket.display_id,
          full_domain: source_ticket.portal.host
        )}
        <br/><br/>
        <b>#{I18n.t('Subject')}:</b> #{source_ticket.subject}<br/><br/>
        <b>#{I18n.t('description')}:</b><br/>#{source_ticket.description_html}
      )
    end

    def all_emails_for_target
      emails_list = remove_duplicates(emails_from_sources)
      emails_list.delete_if { |e| reject_email?(parse_email_text(e)[:email]) }
    end

    def emails_from_sources
      emails_list = []
      source_tickets.each do |source|
        emails_list += get_reply_cc_email(source)
        emails_list << add_source_requester(source) if check_source_requester(source)
      end
      emails_list
    end

    def remove_duplicates(emails_list)
      emails_hash = Hash[emails_list.map { |e| [parse_email_text(e)[:email], e] }]
      emails_hash.values
    end

    def reject_email?(email)
      (email == target.requester.email) || get_email_array(target_reply_cc).include?(email)
    end

    def add_source_requester(ticket)
      %(#{ticket.requester.name} <#{ticket.requester.email}>)
    end

    def get_cc_email(ticket)
      ticket.cc_email && ticket.cc_email[:cc_emails] && get_email_array(ticket.cc_email[:cc_emails]) || []
    end

    def get_reply_cc_email(ticket)
      ticket.cc_email && ticket.cc_email[:reply_cc] || []
    end

    def check_source_requester(ticket)
      ticket.requester_has_email? && !(ticket.requester_id == target.requester_id)
    end
end
