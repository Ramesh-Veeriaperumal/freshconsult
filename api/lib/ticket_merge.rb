class TicketMerge
  include Helpdesk::ToggleEmailNotification
  include ParserUtil
  include Redis::RedisKeys
  include Redis::OthersRedis

  attr_accessor :target, :source_tickets, :params, :convert_to_cc, :header, :target_reply_cc
  SOURCE_KEY_EXPIRY = 86_400 * 7

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
    move_source_description_and_notes
    target.header_info = header unless header.blank?
    move_requesters if convert_to_cc
    move_forwarded_emails
    target.save
    add_note_to_target
    true
  rescue => e
    options_hash = { custom_params: { description: 'Ticket Merge Error', params: params } }
    NewRelic::Agent.notice_error(e, options_hash)
    false
  end

  private

    def update_source_tickets
      source_tickets.each do |source_ticket|
        # setting an attr accessor variable for activities
        source_ticket.activity_type = {
          type: 'ticket_merge_source',
          source_ticket_id: [source_ticket.display_id],
          target_ticket_id: [target.display_id]
        }
        close_source_ticket(source_ticket)
        update_header_info(source_ticket.header_info) if source_ticket.header_info
      end
      Tickets::VaultDataCleanupWorker.perform_async(object_ids: source_tickets.map(&:id), action: 'close') if Account.current.secure_fields_enabled?
    end

    def close_source_ticket(source_ticket)
      disable_notification(Account.current)
      source_ticket.parent_ticket = target.id
      source_ticket.bulk_updation = true
      source_ticket.update_attribute(:status, Helpdesk::Ticketfields::TicketStatus::CLOSED)
      enable_notification(Account.current)
    end

    def update_header_info(source_header)
      (source_header[:message_ids] || []).each do |source|
        header[:message_ids] ||= []
        update_source_header(source) unless header[:message_ids].include?(source)
      end
    end

    def update_source_header(source)
      (header[:message_ids] ||= []) << source
      source_key = EMAIL_TICKET_ID % { account_id: Account.current.id, message_id: source }
      set_others_redis_key(source_key, "#{target.display_id}:#{source}", SOURCE_KEY_EXPIRY)
    end

    def move_source_description_and_notes
      MergeTickets.perform_async(
        source_ticket_ids: source_tickets.map(&:display_id),
        target_ticket_id: target.id,
        source_note_private: @params[:note_in_secondary][:private] || false,
        source_note: @params[:note_in_secondary][:body],
        target_note_private: @params[:note_in_primary][:private] || false
      )
    end

    def move_requesters
      reply_cc_emails = all_emails_for_target
      cc_emails = get_email_array(reply_cc_emails)
      return unless cc_emails.any?
      add_requesters_to_target(reply_cc_emails, cc_emails)
    end

    def move_forwarded_emails
      forwarded_emails = forwarded_emails_for_target
      return unless forwarded_emails.any?

      add_forwarded_emails_to_target(forwarded_emails)
    end

    def add_forwarded_emails_to_target(forwarded_emails)
      if target.cc_email.present?
        target.cc_email[:fwd_emails] = get_forwarded_emails(target).concat(forwarded_emails).uniq
      else
        target_cc_email_attribs([], [], forwarded_emails)
      end
    end

    def add_requesters_to_target(reply_cc_emails, cc_emails)
      emails_list = [reply_cc_emails, cc_emails]
      target.cc_email.blank? ? target_cc_email_attribs(*emails_list) : set_target_cc_emails(*emails_list)
    end

    def target_cc_email_attribs(reply_cc_emails, cc_emails, fwd_emails = [])
      target.cc_email = {
        cc_emails: cc_emails,
        fwd_emails: fwd_emails,
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
      is_private ? Account.current.helpdesk_sources.note_source_keys_by_token['note'] : Account.current.helpdesk_sources.note_source_keys_by_token['email']
    end

    def target_note_emails(is_private, type = :to_emails)
      return [] if is_private
      if type == :to_emails
        target.requester.email.lines.to_a
      else
        target.cc_email_hash && target.cc_email_hash[:cc_emails]
      end
    end

    def all_emails_for_target
      emails_list = remove_duplicates(emails_from_sources)
      emails_list.delete_if { |e| reject_email?(parse_email_text(e)[:email]) }
    end

    def forwarded_emails_for_target
      emails_list = remove_duplicates(forwarded_emails_from_sources)
      emails_list.delete_if { |e| parse_email_text(e)[:email] == target.requester.email }
    end

    def emails_from_sources
      emails_list = []
      source_tickets.each do |source|
        emails_list += get_reply_cc_email(source)
        emails_list << add_source_requester(source) if check_source_requester(source)
      end
      emails_list
    end

    def forwarded_emails_from_sources
      emails_list = []
      source_tickets.each do |source|
        emails_list += get_forwarded_emails(source)
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
      ticket.requester.email
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

    def get_forwarded_emails(ticket)
      ticket.cc_email && ticket.cc_email[:fwd_emails] && get_email_array(ticket.cc_email[:fwd_emails]) || []
    end
end
