module Helpdesk::Permission
  module Ticket

    include Helpdesk::Permission::Util

    def can_create_ticket? email
      valid_permissible_user? email
    end

    def permissible_user_emails emails
      valid_emails(Account.current, emails)
    end

    def fetch_ticket_info ticket_data, user, account
      ticket_identifier = Helpdesk::Email::IdentifyTicket.new(ticket_data, user, account)
      ticket = ticket_identifier.belongs_to_ticket
      if ticket.blank? && account.features?(:archive_tickets)
        archive_ticket = ticket_identifier.belongs_to_archive
      end
      return ticket, archive_ticket
    end

    def process_email_ticket_info account, from_email, user
      ticket = fetch_ticket(account, from_email, user)
      if ticket.blank? && account.features?(:archive_tickets)
        archived_ticket = fetch_archived_ticket(account, from_email, user)
      end
      return ticket, archived_ticket
    end

    def fetch_permissible_cc(user, cc_emails, account = Account.current)
      return cc_emails, [] unless account.restricted_helpdesk?
      if user.blank? || user.customer?
        emails = permissible_user_emails(cc_emails)
        return emails[:valid_emails], emails[:dropped_emails].split(",")
      end
    end

  end
end