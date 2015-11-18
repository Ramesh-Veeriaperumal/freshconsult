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

	def parse_all_cc_emails(kbase_email)
		to_email  = parse_to_email[:email]
   	to_emails = get_email_array(params[:to])
   	cc_emails = to_emails.push(parse_cc_email).flatten.compact.uniq	
   	cc_emails.reject{ |cc_email| (cc_email == kbase_email or cc_email == to_email) }
	end
	
end
