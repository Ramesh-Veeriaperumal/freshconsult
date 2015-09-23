module Integrations::Hootsuite::TicketsHelper
	include Helpdesk::TicketsHelper
	include Helpdesk::NotesHelper

	def to_cc_emails
  	if @ticket_note_all.blank?
      @ticket.reply_to_all_emails
    else
      @ticket.current_cc_emails
    end
  end
end