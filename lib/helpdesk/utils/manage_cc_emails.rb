# encoding: utf-8
module Helpdesk::Utils::ManageCcEmails

	include ParserUtil

	def add_to_reply_cc(new_cc_emails, ticket, note, ticket_cc_hash)
		note_creator = parse_email(note.user.email)[:email]
		return if ticket.included_in_fwd_emails?(note_creator)
		ticket_cc_hash[:reply_cc] = (new_cc_emails | ((ticket_cc_hash[:cc_emails] || []).find { |ccs| ccs.include?(note_creator.to_s) }).to_a)
	end

	# To emails in Cc code to come here...
	# https://support.freshdesk.com/helpdesk/tickets/100762
end