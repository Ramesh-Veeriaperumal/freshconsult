# encoding: utf-8
module Helpdesk::Utils::ManageCcEmails

	include ParserUtil

	def add_to_reply_cc(new_cc_emails, ticket, note, ticket_cc_hash)
		note_creator = parse_email(note.user.email)[:email]
		return if ticket.included_in_fwd_emails?(note_creator)
		if ticket.requester_id == note.user_id || note.user.agent?
			ticket_cc_hash[:reply_cc] = new_cc_emails
		else
			email_hash = ticket_cc_hash[:reply_cc].map {|cc| parse_email(cc)[:email] }
			ticket_cc_hash[:reply_cc] = ticket_cc_hash[:reply_cc] + (new_cc_emails.reject {|cc| email_hash.include?(parse_email(cc)[:email])})
		end
	end

	# To emails in Cc code to come here...
	# https://support.freshdesk.com/helpdesk/tickets/100762
end