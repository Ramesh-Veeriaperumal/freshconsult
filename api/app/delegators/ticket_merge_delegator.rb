class TicketMergeDelegator < BaseDelegator
  include ParserUtil

  attr_accessor :source_tickets, :convert_to_cc, :ticket_ids, :display_id

  validate :reply_cc_limit
  validate :validate_source_tickets

  def initialize(record, options = {})
    super(record)
    @source_tickets = options[:source_tickets]
    @convert_to_cc = options[:convert_recepients_to_cc]
    @ticket_ids = options[:ticket_ids]
  end

  private

    def reply_cc_limit
      return true unless @convert_to_cc
      if (emails_in_sources.size + get_reply_cc(self).size) > TicketConstants::MAX_EMAIL_COUNT
        errors[:convert_recepients_to_cc] << :max_limit_page
      end
    end

    def validate_source_tickets
      if invalid_ticket_ids.present? || access_denied_ids.present?
        errors[:ticket_ids] << invalid_error_code
        (self.error_options ||= {}).merge!(invalid_ids_option)
      end
    end

    def invalid_error_code
      if invalid_ticket_ids.present?
        return :access_denied_and_invalid_list if access_denied_ids.present?
        :invalid_list
      else
        :access_denied_list
      end
    end

    def access_denied_ids
      @denied_ids ||= @source_tickets.select { |ticket| !ticket_permission?(ticket) }.map(&:display_id)
    end

    def invalid_ticket_ids
      @invalid_ids ||= @ticket_ids - @source_tickets.map(&:display_id)
    end

    def invalid_ids_option
      {
        ticket_ids: {
          list: invalid_ticket_ids.join(', '),
          denied_ids: access_denied_ids.join(', ')
        }
      }
    end

    def emails_in_sources
      emails_list = remove_duplicates(combined_emails)
      emails_list.delete_if { |e| reject_email?(parse_email_text(e)[:email]) }
    end

    def combined_emails
      emails_list = []
      @source_tickets.each do |source|
        emails_list += get_reply_cc(source)
        emails_list << add_source_requester(source) if check_source_requester(source)
      end
      emails_list
    end

    def remove_duplicates(emails_list)
      emails_hash = Hash[emails_list.map { |e| [parse_email_text(e)[:email], e] }]
      emails_hash.values
    end

    def reject_email?(email)
      email == requester.email || get_email_array(get_reply_cc(self)).include?(email)
    end

    def add_source_requester(ticket)
      %(#{ticket.requester.name} <#{ticket.requester.email}>)
    end

    def get_reply_cc(ticket)
      ticket.cc_email && ticket.cc_email[:reply_cc] || []
    end

    def check_source_requester(ticket)
      ticket.requester_has_email? && !(ticket.requester_id == requester_id)
    end

    def ticket_permission?(ticket)
      User.current.has_ticket_permission?(ticket) || !ticket.schema_less_ticket.try(:trashed)
    end
end
