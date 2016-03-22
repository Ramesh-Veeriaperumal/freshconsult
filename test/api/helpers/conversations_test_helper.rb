module ConversationsTestHelper
  include NoteHelper
  include TicketHelper

  def note_pattern(expected_output = {}, note)
    body_html = format_ticket_html(note, expected_output[:body]) if expected_output[:body]
    {
      body: body_html || note.body_html,
      body_text: note.body,
      id: Fixnum,
      incoming: (expected_output[:incoming] || note.incoming).to_s.to_bool,
      private: (expected_output[:private] || note.private).to_s.to_bool,
      user_id: expected_output[:user_id] || note.user_id,
      support_email: note.support_email,
      ticket_id: expected_output[:ticket_id] || note.notable_id,
      to_emails: expected_output[:notify_emails] || note.to_emails,
      attachments: Array,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def update_note_pattern(expected_output = {}, note)
    body = expected_output[:body] || note.body_html
    note_pattern(expected_output, note).merge(body: body)
  end

  def index_note_pattern(note)
    index_note = {
      from_email: note.from_email,
      cc_emails:  note.cc_emails,
      bcc_emails: note.bcc_emails,
      source: note.source
    }
    single_note = note_pattern({}, note)
    single_note.merge(index_note)
  end

  def reply_note_pattern(expected_output = {}, note)
    body_html = format_ticket_html(note, expected_output[:body]) if expected_output[:body]
    {
      body: body_html || note.body_html,
      body_text: note.body,
      id: Fixnum,
      user_id: expected_output[:user_id] || note.user_id,
      from_email: note.from_email,
      cc_emails: expected_output[:cc_emails] || note.cc_emails,
      bcc_emails: expected_output[:bcc_emails] || note.bcc_emails,
      ticket_id: expected_output[:ticket_id] || note.notable_id,
      to_emails: note.to_emails,
      attachments: Array,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def v1_note_payload
    { helpdesk_note: { body: Faker::Lorem.paragraph, to_emails: [Faker::Internet.email, Faker::Internet.email], private: true } }.to_json
  end

  def v2_note_payload
    agent_email1 = @agent.email
    agent_email2 = User.find { |x| x.email != agent_email1 && x.helpdesk_agent == true }.try(:email) || add_test_agent(@account, role: Role.find_by_name('Agent').id).email || add_test_agent(@account, role: Role.find_by_name('Agent').id).email
    { body: Faker::Lorem.paragraph, notify_emails: [agent_email1, agent_email2], private: true }.to_json
  end

  def v2_note_update_payload
    { body: Faker::Lorem.paragraph }.to_json
  end

  def v1_reply_payload
    { helpdesk_note: { body: Faker::Lorem.paragraph, source: 0, private: false,  cc_emails: [Faker::Internet.email, Faker::Internet.email], bcc_emails: [Faker::Internet.email, Faker::Internet.email] } }.to_json
  end

  def v2_reply_payload
    { body:  Faker::Lorem.paragraph, cc_emails: [Faker::Internet.email, Faker::Internet.email], bcc_emails: [Faker::Internet.email, Faker::Internet.email] }.to_json
  end
end
