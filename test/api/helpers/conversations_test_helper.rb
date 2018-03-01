['note_helper.rb', 'ticket_helper.rb', 'email_configs_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module ConversationsTestHelper
  include NoteHelper
  include TicketHelper
  include EmailConfigsHelper

  def note_pattern(expected_output, note)
    body_html = format_ticket_html(note, expected_output[:body]) if expected_output[:body]
    {
      body: body_html || note.body_html,
      body_text: note.body,
      id: Fixnum,
      incoming: (expected_output[:incoming] || note.incoming).to_s.to_bool,
      private: (expected_output[:private] || note.private).to_s.to_bool,
      user_id: expected_output[:user_id] || note.user_id,
      support_email: note.support_email,
      ticket_id: expected_output[:ticket_id] || note.notable.display_id,
      to_emails: expected_output[:notify_emails] || note.to_emails,
      category: note.category,
      attachments: Array,
      email_failure_count: note.schema_less_note.failure_count,    
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def v2_note_pattern(expected_output, note)
    body_html = format_ticket_html(note, expected_output[:body]) if expected_output[:body]
    {
      body: body_html || note.body_html,
      body_text: note.body,
      id: Fixnum,
      incoming: (expected_output[:incoming] || note.incoming).to_s.to_bool,
      private: (expected_output[:private] || note.private).to_s.to_bool,
      user_id: expected_output[:user_id] || note.user_id,
      support_email: note.support_email,
      ticket_id: expected_output[:ticket_id] || note.notable.display_id,
      to_emails: expected_output[:notify_emails] || note.to_emails,
      attachments: Array,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def private_note_pattern(expected_output, note)
    if expected_output[:from_email]
      email_config = @account.email_configs.where(reply_email: expected_output[:from_email]).first
      expected_output[:from_email] = @account.features?(:personalized_email_replies) ? email_config.friendly_email_personalize(note.user.name) : email_config.friendly_email if email_config
    end

    response_pattern = note_pattern(expected_output, note).merge(deleted: (expected_output[:deleted] || note.deleted).to_s.to_bool,
                                                                 source: (expected_output[:source] || note.source),
                                                                 user_id: (expected_output[:user_id] || expected_output[:agent_id] || note.user_id),
                                                                 from_email: (expected_output[:from_email] || note.from_email),
                                                                 to_emails: expected_output[:notify_emails] || expected_output[:to_emails] || note.to_emails,
                                                                 cc_emails: expected_output[:cc_emails] || note.cc_emails,
                                                                 bcc_emails: expected_output[:bcc_emails] || note.bcc_emails,
                                                                 cloud_files: Array,
                                                                 has_quoted_text: (note.full_text_html.length > note.body_html.length),
                                                                 last_edited_at: note.last_modified_timestamp.try(:utc).try(:iso8601),
                                                                 last_edited_user_id: note.last_modified_user_id.try(:to_i))

    if note.fb_note? && note.fb_post.present?
      fb_pattern = note.fb_post.post? ? fb_post_pattern({}, note.fb_post) : fb_dm_pattern({}, note.fb_post)
      response_pattern[:fb_post] = fb_pattern
    end

    if note.tweet? && note.tweet
      response_pattern[:tweet] = tweet_pattern({}, note.tweet)
    end

    if note.feedback?
      survey = note.custom_survey_remark.survey_result
      response_pattern[:survey_result] = feedback_pattern(survey)
    end

    response_pattern
  end

  def feedback_pattern(survey_result)
    {
      survey_id: survey_result.survey_id,
      agent_id: survey_result.agent_id,
      group_id: survey_result.group_id,
      rating: survey_result.custom_ratings
    }
  end

  def update_note_pattern(expected_output, note)
    body = expected_output[:body] || note.body_html
    note_pattern(expected_output, note).merge(body: body)
  end

  def v2_update_note_pattern(expected_output, note)
    body = expected_output[:body] || note.body_html
    v2_note_pattern(expected_output, note).merge(body: body)
  end

  def private_update_note_pattern(expected_output, note)
    body = expected_output[:body] || note.body_html
    private_note_pattern(expected_output, note).merge(body: body)
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

  def reply_note_pattern(expected_output, note)
    body_html = format_ticket_html(note, expected_output[:body]) if expected_output[:body]
    {
      body: body_html || note.body_html,
      body_text: note.body,
      id: Fixnum,
      user_id: expected_output[:user_id] || note.user_id,
      from_email: note.from_email,
      cc_emails: expected_output[:cc_emails] || note.cc_emails,
      bcc_emails: expected_output[:bcc_emails] || note.bcc_emails,
      ticket_id: expected_output[:ticket_id] || note.notable.display_id,
      to_emails: note.to_emails,
      attachments: Array,
      broadcast_note: expected_output[:broadcast_note] || note.broadcast_note?,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def v2_reply_note_pattern(expected_output, note)
    body_html = format_ticket_html(note, expected_output[:body]) if expected_output[:body]
    {
      body: body_html || note.body_html,
      body_text: note.body,
      id: Fixnum,
      user_id: expected_output[:user_id] || note.user_id,
      from_email: note.from_email,
      cc_emails: expected_output[:cc_emails] || note.cc_emails,
      bcc_emails: expected_output[:bcc_emails] || note.bcc_emails,
      ticket_id: expected_output[:ticket_id] || note.notable.display_id,
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
    { helpdesk_note: { body: Faker::Lorem.paragraph, source: 0, private: false, cc_emails: [Faker::Internet.email, Faker::Internet.email], bcc_emails: [Faker::Internet.email, Faker::Internet.email] } }.to_json
  end

  def v2_reply_payload
    { body:  Faker::Lorem.paragraph, cc_emails: [Faker::Internet.email, Faker::Internet.email], bcc_emails: [Faker::Internet.email, Faker::Internet.email] }.to_json
  end

  def v1_forward_payload
    { helpdesk_note: { body: Faker::Lorem.paragraph, to_emails: [Faker::Internet.email, Faker::Internet.email], cc_emails: [Faker::Internet.email, Faker::Internet.email], bcc_emails: [Faker::Internet.email, Faker::Internet.email], source: 8, private: true } }.to_json
  end

  def v2_forward_payload
    { body:  Faker::Lorem.paragraph, to_emails: [Faker::Internet.email, Faker::Internet.email], cc_emails: [Faker::Internet.email, Faker::Internet.email], bcc_emails: [Faker::Internet.email, Faker::Internet.email] }.to_json
  end

  def conversation_template_pattern(expected_output)
    {
      template: expected_output[:template],
      signature: expected_output[:signature],
      quoted_text: expected_output[:quoted_text] || String,
      bcc_emails: expected_output[:bcc_emails] || Array
    }
  end

  def reply_template_pattern(expected_output)
    conversation_template_pattern(expected_output).merge(cc_emails: Array)
  end

  def forward_template_pattern(expected_output)
    reply_template_pattern(expected_output).merge(attachments: Array, cloud_files: Array)
  end

  def reply_to_forward_template_pattern(expected_output)
    conversation_template_pattern(expected_output).merge(cc_emails: Array, to_emails: Array)
  end

  def full_text_pattern(note)
    {
      text: note.note_body.full_text,
      html: note.note_body.full_text_html
    }
  end

  def create_broadcast_note(ticket_id, params = {})
    broadcast_params = {
      ticket_id: ticket_id,
      source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
      user_id: @agent.id,
      account_id: @account.id,
      notable_type: 'Helpdesk::Ticket',
      body: Faker::Lorem.paragraph,
      private: true,
      category: Helpdesk::Note::CATEGORIES[:broadcast]
    }.merge(params)
    create_note broadcast_params
  end

  def create_broadcast_message(tracker_id, note_id)
    @account.broadcast_messages.create(tracker_display_id: tracker_id, body_html: Faker::Lorem.paragraph, note_id: note_id)
  end
end
