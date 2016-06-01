# encoding: utf-8
module Helpdesk::Utils::ManageCcEmails

  include ParserUtil

  def override_reply_cc?(references)
    !EmailHelper::AUTOMATED_EMAIL_MESSAGE_IDS.any?{|msg_id| references.include?(msg_id[1])}
  end

  def add_to_reply_cc(new_cc_emails, ticket, note, ticket_cc_hash, references)
    note_creator = parse_email(note.user.email)[:email]
    return if ticket.included_in_fwd_emails?(note_creator)

    # if a note is from requester/agent and not a reply to notification/automation email thread then replace the existing reply_cc with new CC
    if((ticket.requester_id == note.user_id || note.user.agent? ) && override_reply_cc?(references))
      ticket_cc_hash[:reply_cc] = new_cc_emails
    # if note is from requester or agent or from anyone in ticket CC, then append to reply_cc
    elsif ticket.requester_id == note.user_id || note.user.agent? || ticket_cc_hash[:tkt_cc].include?(note.user)
      email_hash = ticket_cc_hash[:reply_cc].map {|cc| parse_email(cc)[:email] }
      ticket_cc_hash[:reply_cc] = ticket_cc_hash[:reply_cc] + (new_cc_emails.reject {|cc| email_hash.include?(parse_email(cc)[:email])})
    end
  end

  def parse_all_cc_emails(kbase_email, support_emails)
    to_email   = parse_to_email[:email]
    to_emails  = get_email_array(params[:to])
    sup_emails = support_emails.map(&:downcase)
    additional_to_emails = to_emails.reject{ |cc_email| ((cc_email == kbase_email) or (cc_email == to_email) or sup_emails.include?(cc_email.downcase))}
    additional_to_emails.push(parse_cc_email).flatten.compact.uniq
  end

end

