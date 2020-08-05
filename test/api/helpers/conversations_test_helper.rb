['note_helper.rb', 'ticket_helper.rb', 'email_configs_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module ConversationsTestHelper
  include NoteHelper
  include TicketHelper
  include EmailConfigsHelper

  def note_pattern(expected_output, note)
    schema_less_properties = note.schema_less_note.try(:note_properties) || {}
    response_hash = {
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
      outgoing_failures: schema_less_properties[:errors],
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    construct_note_body_hash(expected_output, note).merge(response_hash)
  end

  def archive_note_pattern(expected_output, archive_note)
    body_html = format_ticket_html(expected_output[:body]) if expected_output[:body]
    {
      body: body_html || archive_note.body_html,
      body_text: expected_output[:body] || archive_note.body,
      id: Fixnum,
      incoming: (expected_output[:incoming] || archive_note.incoming).to_s.to_bool,
      private: (expected_output[:private] || archive_note.private).to_s.to_bool,
      user_id: expected_output[:user_id] || archive_note.user_id,
      support_email: archive_note.support_email,
      ticket_id: expected_output[:ticket_id] || archive_note.notable.display_id,
      attachments: Array,
      to_emails: archive_note.to_emails,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def v2_note_pattern(expected_output, note)
    body_html = format_ticket_html(expected_output[:body]) if expected_output[:body]
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

  def show_note_pattern(expected_output, note)
    v2_note_pattern(expected_output, note).merge(source_additional_info: source_additional_info(note))
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

  def update_ticket_summary_pattern(expected_output, note)
    body = expected_output[:body] || note.body_html
    ticket_summary_pattern(expected_output, note).merge(body: body)
  end

  def update_private_ticket_summary_pattern(expected_output, note)
    body = expected_output[:body] || note.body_html
    private_ticket_summary_pattern(expected_output, note).merge(body: body)
  end

  def index_note_pattern(note)
    index_note = {
      from_email: note.from_email,
      cc_emails:  note.cc_emails,
      bcc_emails: note.bcc_emails,
      source: note.source,
      source_additional_info: source_additional_info(note)
    }
    single_note = note_pattern({}, note)
    single_note.merge(index_note)
  end

  def reply_note_pattern(expected_output, note)
    body_html = format_ticket_html(expected_output[:body]) if expected_output[:body]
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
    body_html = format_ticket_html(expected_output[:body]) if expected_output[:body]
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
      source_additional_info: source_additional_info(note),
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
      source: Account.current.helpdesk_sources.note_source_keys_by_token['note'],
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

  def ticket_summary_pattern(expected_output, note)
     body_html = format_ticket_html(expected_output[:body]) if expected_output[:body]
    {
      body: body_html || note.body_html,
      body_text: note.body,
      id: Fixnum,
      user_id: expected_output[:user_id] || note.user_id,
      ticket_id: expected_output[:ticket_id] || note.notable.display_id,
      attachments: Array,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      last_edited_at: note.last_modified_timestamp.try(:utc).try(:iso8601),
      last_edited_user_id: note.last_modified_user_id.try(:to_i)
    }
  end

  def private_ticket_summary_pattern(expected_output, note)
    response_pattern = ticket_summary_pattern(expected_output, note).merge(
                        cloud_files: Array)
  end

  def tweet_info_hash(note)
    return {} unless note.tweet? && note.tweet && note.tweet.twitter_handle

    handle = note.tweet.twitter_handle
    tweet_hash = {
      id: note.tweet.tweet_id.to_i > 0 ? note.tweet.tweet_id.to_s : nil,
      type: note.tweet.tweet_type,
      support_handle_id: handle.twitter_user_id.to_s,
      support_screen_name: handle.screen_name,
      requester_screen_name: Account.current.twitter_api_compliance_enabled? && !CustomRequestStore.store[:channel_api_request] ? nil : note.user.twitter_id
    }
    tweet_hash[:stream_id] = note.tweet.stream_id if @channel_v2_api
    tweet_hash
  end

  def facebook_post_hash(note)
    return {} unless note.present? && note.fb_note? && note.fb_post.present? && note.fb_post.facebook_page.present?

    ret_hash = {
      id: note.fb_post.post_id.to_i > 0 ? note.fb_post.post_id.to_s : nil,
      type: note.fb_post.msg_type
    }
    ret_hash[:post_type] = Facebook::Constants::CODE_TO_POST_TYPE[note.fb_post.post_attributes[:post_type]] if note.fb_post.post? && note.fb_post.post_type_present?
    ret_hash
  end

  def source_additional_info(note)
    source_info = {}
    tweet = tweet_info_hash(note)
    fb_post_hash = facebook_post_hash(note)
    source_info[:twitter] = tweet if tweet.present?
    source_info[:facebook] = fb_post_hash if fb_post_hash.present?
    source_info.presence
  end

  def default_body_hash(expected_output, note)
    body_html = format_ticket_html(expected_output[:body]) if expected_output[:body]
    {
      body: body_html || note.body_html,
      body_text: note.body
    }
  end

  def restrict_twitter_content?(note)
    Account.current.twitter_api_compliance_enabled? && !CustomRequestStore.store[:private_api_request] && !CustomRequestStore.store[:channel_api_request] && note.incoming && note.tweet.present?
  end

  def twitter_public_api_body_hash(body)
    {
      body: body,
      body_text: body
    }
  end

  def construct_note_body_hash(expected_output, note)
    tweet_record = note.tweet
    return default_body_hash(expected_output, note) unless restrict_twitter_content?(note)

    if tweet_record.tweet_type == Social::Twitter::Constants::TWITTER_NOTE_TYPE[:mention]
      tweet_body = "View the tweet at https://twitter.com/#{tweet_record.twitter_handle_id}/status/#{tweet_record.tweet_id}"
      return twitter_public_api_body_hash(tweet_body)
    else
      dm_body = 'View the message at https://twitter.com/messages'
      return twitter_public_api_body_hash(dm_body)
    end
  end

  def validation_error_pattern(value)
    {
      description: 'Validation failed',
      errors: [value]
    }
  end
end
