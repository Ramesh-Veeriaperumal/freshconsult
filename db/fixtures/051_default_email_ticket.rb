account = Account.current

#Step 1 ticket creation
user = User.seed(:account_id, :email) do |s|
  s.account_id  = account.id
  s.email       = Helpdesk::AGENT[:email]
  s.name        = Helpdesk::AGENT[:name]
end

args = { :role_ids => account.roles.agent.first.id, :occasional => true }
user.make_agent(args)
agent = user


requester = User.seed(:account_id, :email) do |s|
  s.account_id = account.id
  s.email      = Helpdesk::DEFAULT_TICKET_REQUESTER[:email_ticket][:email]
  s.name       = Helpdesk::DEFAULT_TICKET_REQUESTER[:email_ticket][:name]
end

description_html = I18n.t(:'default.ticket.email.body', :onclick => "inline_manual_player.activateTopic(17777);")
description = Helpdesk::HTMLSanitizer.html_to_plain_text(description_html)

ticket = Helpdesk::Ticket.seed(:account_id, :subject) do |s|
  s.account_id  = account.id
  s.subject     = I18n.t(:'default.ticket.email.subject')
  s.email       = Helpdesk::DEFAULT_TICKET_REQUESTER[:email_ticket][:email]
  s.status      = Helpdesk::Ticketfields::TicketStatus::OPEN
  s.source      = TicketConstants::SOURCE_KEYS_BY_TOKEN[:email]
  s.priority    = TicketConstants::PRIORITY_KEYS_BY_TOKEN[:high]
  s.ticket_type = Helpdesk::Ticket::TYPE_NAMES_BY_SYMBOL[:incident]
  s.cc_email    = Helpdesk::Ticket.default_cc_hash
  s.status      = Helpdesk::TicketStatus::OPEN
  s.disable_observer_rule   = true
  s.ticket_body_attributes  = {:description => description, :description_html => description_html }
  s.disable_activities      = true
end

#Activity gets called at the end of commit transaction(Whole seed transaction.) Hence added here explicitly.
ticket.create_activity(requester, "activities.tickets.new_ticket.long", {}, "activities.tickets.new_ticket.short") 

#Step 2 replying ticket
note_body_html = I18n.t(:'default.ticket.email.reply')
note_body = Helpdesk::HTMLSanitizer.html_to_plain_text(note_body_html)

reply_note = ticket.notes.new(
  :user_id      => agent.id,
  :source       => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"],
  :private      => false,
  :note_body_attributes  => {:body_html => note_body_html},
  :skip_notification     => true,
  :disable_observer_rule => true
  )

reply_note.notable.disable_observer_rule = true
reply_note.save_note!

#current_user is reset so that survey goes from customer.
current_user = User.current
User.reset_current_user

#Step 3 customer satisfaction using survey.
survey = account.custom_surveys.default.first

survey_handle = ticket.custom_survey_handles.build(
  :survey => survey,
  :sent_while => CustomSurvey::Survey::CLOSED_NOTIFICATION
  )

survey_handle.record_survey_result  CustomSurvey::Survey::CUSTOMER_RATINGS_BY_TOKEN["extremely_happy"]

current_user.make_current
