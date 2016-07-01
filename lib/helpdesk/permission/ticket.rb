module Helpdesk::Permission
  module Ticket

    include Helpdesk::Permission::Util

    def can_create_ticket? email
      valid_permissible_user? email
    end

    def permissible_user_emails emails
      valid_emails(Account.current, emails)
    end

    #todo: to chk possibility of merging fetch_ticket_info & process_email_ticket_info
    def fetch_ticket_info ticket_data, user, account
      ticket_identifier = Helpdesk::Email::IdentifyTicket.new(ticket_data, user, account)
      ticket = ticket_identifier.belongs_to_ticket
      if ticket.blank? && account.features?(:archive_tickets)
        archive_ticket = ticket_identifier.belongs_to_archive
      end
      return ticket, archive_ticket
    end

    def process_email_ticket_info account, from_email, user, email_config
      ticket = fetch_ticket(account, from_email, user, email_config)
      if ticket.blank? && account.features_included?(:archive_tickets)
        archived_ticket = fetch_archived_ticket(account, from_email, user, email_config)
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