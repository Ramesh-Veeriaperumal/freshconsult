# encoding: utf-8
module Helpdesk::Utils::ManageCcEmails

	include ParserUtil

  def updated_ticket_cc_emails(new_cc_emails, ticket, note, in_reply_to, 
    to_email, to_emails)
    ticket_cc_hash = ticket.cc_email_hash.presence || Helpdesk::Ticket.default_cc_hash
    support_emails = ticket.account.support_emails
    begin
      new_cc_emails.delete_if{ |email| (email == ticket.requester.email)}
      filtered_cc_emails = filter_cc_emails(new_cc_emails, to_email, to_emails, ticket.account.kbase_email, support_emails)
      note_creator = parse_email(note.user.email)[:email]
      return ticket_cc_hash if ticket.included_in_fwd_emails?(note_creator)

      if in_reply_to.to_s.include?(Helpdesk::EMAIL_TYPE_TO_MESSAGE_ID_DOMAIN[:notification]) || 
        in_reply_to.to_s.include?(Helpdesk::EMAIL_TYPE_TO_MESSAGE_ID_DOMAIN[:automation])
        # if it is reply to notification email or scenario automation email 
        # and note is from requester or agent or from anyone in ticket Cc, 
        # then append to reply_cc
        if(ticket.requester_id == note.user_id || note.user.agent? || 
          (ticket_cc_hash[:tkt_cc] || []).include?(note.user.email))
          ticket_cc_hash[:reply_cc] = (ticket_cc_hash[:reply_cc] || []).map!{ 
            |cc| parse_email(cc)[:email]}.compact
          filtered_cc_emails = filtered_cc_emails.reject {|cc| 
            ticket_cc_hash[:reply_cc].include?(cc)}
          # concatination of existing reply_cc with with reply_cc
          ticket_cc_hash[:reply_cc][ticket_cc_hash[:reply_cc].length, 0] = filtered_cc_emails
        else
          Rails.logger.debug "Reply for email notification or scenario automation 
            mail, but not from agent/requester/users in ticket-cc in_reply_to : 
            #{in_reply_to.to_s} and note.user_id : #{note.user_id.to_s}"
          return ticket_cc_hash
        end
      elsif (ticket_cc_hash[:cc_emails] || []).include?(note.user.email) && !note.third_party_response?
        support_emails = support_emails.map(&:downcase)
        # Rejecting multiple occurences of same CC email and support email addresses
        filtered_cc_emails = filtered_cc_emails.reject do |cc|
          ticket_cc_hash[:reply_cc].include?(cc) || support_emails.include?(cc.downcase)
        end
        # if the note is from customer who has been CC'ed and not a reply to notification or automation mail
        # then concatenate the existing reply CC with new_cc_emails
        ticket_cc_hash[:reply_cc][ticket_cc_hash[:reply_cc].length, 0] = filtered_cc_emails
      elsif ((ticket.requester_id == note.user_id || note.user.agent?) && !note.third_party_response?)
        # if the note is from requester or agent and not a reply to notification
        # or automation mail then replace the existing reply_cc with new Cc
        ticket_cc_hash[:reply_cc] = filtered_cc_emails
      else
        Rails.logger.debug "Its not a reply of email notification or scenario 
        automation mail and from agent/requester, in_reply_to : #{in_reply_to.to_s} 
        and note.user_id : #{note.user_id.to_s}"
        return ticket_cc_hash
      end

      filtered_cc_emails = filtered_cc_emails.reject{ 
        |cc| ticket_cc_hash[:cc_emails].include?(cc) }
      ticket_cc_hash[:cc_emails][ticket_cc_hash[:cc_emails].length, 0] = filtered_cc_emails
    rescue => ex
      Rails.logger.error "Exception on constructing updated 
      ticket_cc_hash : #{ex.message}, new_cc_emails : #{new_cc_emails}, 
      to_emails: #{to_emails}, to_email : #{to_email}"
    end
    ticket_cc_hash
  end

	def parse_all_cc_emails(kbase_email, support_emails)
    to_email   = parse_to_email[:email]
    to_emails  = get_email_array(params[:to])
   	new_cc_emails = parse_cc_email
    filter_cc_emails(new_cc_emails, to_email, to_emails, kbase_email, 
      support_emails)
	end

  def filter_cc_emails(new_cc_emails, to_email, to_emails, kbase_email, 
    support_emails)
    sup_emails = support_emails.map(&:downcase)
    additional_to_emails = to_emails.reject{ |cc_email| 
      ((cc_email == kbase_email) or (cc_email == to_email) or 
        sup_emails.include?(cc_email.downcase))}
    additional_to_emails[additional_to_emails.length, 0] = new_cc_emails
    additional_to_emails.compact.uniq
  end

end

