['ticket_fields_test_helper.rb', 'conversations_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['ticket_helper.rb', 'company_helper.rb', 'group_helper.rb', 'note_helper.rb', 'email_configs_helper.rb', 'products_helper.rb', 'freshfone_spec_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require "#{Rails.root}/spec/helpers/social_tickets_helper.rb"
module TicketsTestHelper
  include GroupHelper
  include ConversationsTestHelper
  include TicketFieldsTestHelper
  include EmailConfigsHelper
  include ProductsHelper
  include CompanyHelper
  include TicketHelper
  include NoteHelper
  include SocialTicketsHelper
  include FreshfoneSpecHelper
  include ForumHelper

  # Patterns
  def deleted_ticket_pattern(expected_output = {}, ticket)
    ticket_pattern(expected_output, ticket).merge(deleted: (expected_output[:deleted] || ticket.deleted).to_s.to_bool)
  end

  def index_ticket_pattern(ticket, exclude = [])
    ticket_pattern(ticket).except(*([:attachments, :conversations, :tags] - exclude))
  end

  def index_ticket_pattern_with_associations(ticket, requester = true, ticket_states = true, company = true, exclude = [])
    ticket_pattern_with_association(
      ticket, false, false, requester,
      company, ticket_states
    ).except(*([:attachments, :conversations, :tags] - exclude))
  end

  def index_deleted_ticket_pattern(ticket)
    index_ticket_pattern(ticket).merge(deleted: ticket.deleted.to_s.to_bool)
  end

  def ticket_pattern_with_notes(ticket, limit = false)
    notes_pattern = []
    ticket.notes.visible.exclude_source('meta').order(:created_at).each do |n|
      notes_pattern << index_note_pattern(n)
    end
    notes_pattern = notes_pattern.take(limit) if limit
    ticket_pattern(ticket).merge(conversations: notes_pattern.ordered!)
  end

  def ticket_pattern_with_association(ticket, limit = false, notes = true, requester = true, company = true, stats = true)
    result_pattern = ticket_pattern(ticket)
    if notes
      notes_pattern = []
      ticket.notes.visible.exclude_source('meta').order(:created_at).each do |n|
        notes_pattern << index_note_pattern(n)
      end
      notes_pattern = notes_pattern.take(10) if limit
      result_pattern.merge!(conversations: notes_pattern.ordered!)
    end
    if requester
      ticket.requester ? result_pattern.merge!(requester: requester_pattern(ticket.requester)) : result_pattern.merge!(requester: {})
    end
    if company
      ticket.company ? result_pattern.merge!(company: company_pattern(ticket.company)) : result_pattern.merge!(company: {})
    end
    if stats
      ticket.ticket_states ? result_pattern.merge!(stats: ticket_states_pattern(ticket.ticket_states)) : result_pattern.merge!(stats: {})
    end
    result_pattern
  end

  def requester_pattern(requester)
    {
      id: requester.id,
      name: requester.name,
      email: requester.email,
      mobile: requester.mobile,
      phone: requester.phone
    }
  end

  def company_pattern(company)
    {
      id: company.id,
      name: company.name
    }
  end

  def ticket_states_pattern(ticket_states)
    {
      closed_at: ticket_states.closed_at.try(:utc).try(:iso8601),
      resolved_at: ticket_states.resolved_at.try(:utc).try(:iso8601),
      first_responded_at: ticket_states.first_response_time.try(:utc).try(:iso8601)
    }
  end

  def feedback_pattern(survey_result)
    {
      survey_id: survey_result.survey_id,
      agent_id: survey_result.agent_id, 
      group_id: survey_result.group_id, 
      rating: survey_result.custom_ratings
    }
  end

  def ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    expected_custom_field = (expected_output[:custom_fields] && ignore_extra_keys) ? expected_output[:custom_fields].ignore_extra_keys! : expected_output[:custom_fields]
    custom_field = ticket.custom_field.map { |k, v| [TicketDecorator.display_name(k), v.respond_to?(:utc) ? v.utc.iso8601 : v] }.to_h
    ticket_custom_field = (custom_field && ignore_extra_keys) ? custom_field.as_json.ignore_extra_keys! : custom_field.as_json
    description_html = format_ticket_html(ticket, expected_output[:description]) if expected_output[:description]

    {
      cc_emails: expected_output[:cc_emails] || ticket.cc_email && ticket.cc_email[:cc_emails],
      fwd_emails: expected_output[:fwd_emails] || ticket.cc_email && ticket.cc_email[:fwd_emails],
      reply_cc_emails:  expected_output[:reply_cc_emails] || ticket.cc_email && ticket.cc_email[:reply_cc],
      description:  description_html || ticket.description_html,
      description_text:  ticket.description,
      id: expected_output[:display_id] || ticket.display_id,
      fr_escalated:  (expected_output[:fr_escalated] || ticket.fr_escalated).to_s.to_bool,
      is_escalated:  (expected_output[:is_escalated] || ticket.isescalated).to_s.to_bool,
      spam:  (expected_output[:spam] || ticket.spam).to_s.to_bool,
      email_config_id:  expected_output[:email_config_id] || ticket.email_config_id,
      group_id:  expected_output[:group_id] || ticket.group_id,
      priority:  expected_output[:priority] || ticket.priority,
      requester_id:  expected_output[:requester_id] || ticket.requester_id,
      responder_id:  expected_output[:responder_id] || ticket.responder_id,
      source: expected_output[:source] || ticket.source,
      status: expected_output[:status] || ticket.status,
      subject:  expected_output[:subject] || ticket.subject,
      company_id: expected_output[:company_id] || ticket.company_id,
      type:  expected_output[:ticket_type] || ticket.ticket_type,
      to_emails: expected_output[:to_emails] || ticket.to_emails,
      product_id:  expected_output[:product_id] || ticket.product_id,
      attachments: Array,
      tags:  expected_output[:tags] || ticket.tag_names,
      custom_fields:  expected_custom_field || ticket_custom_field,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      due_by: expected_output[:due_by].try(:to_time).try(:utc).try(:iso8601) || ticket.due_by.try(:utc).try(:iso8601),
      fr_due_by: expected_output[:fr_due_by].try(:to_time).try(:utc).try(:iso8601) || ticket.frDueBy.try(:utc).try(:iso8601)
    }
  end

  def create_ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    ticket_pattern(expected_output, ignore_extra_keys, ticket).merge(cloud_files: Array)
  end

  def update_ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    description = expected_output[:description] || ticket.description_html
    ticket_pattern(expected_output, ignore_extra_keys, ticket).merge(description: description, cloud_files: Array)
  end

  def latest_note_response_pattern(note)
    pattern = note_pattern({}, note).merge!({ user: Hash })
    pattern.except(:user_id)
  end

  def reply_draft_pattern(expected_output)
    {
      body: expected_output[:body],
      cc_emails: expected_output[:cc_emails] || [],
      bcc_emails: expected_output[:bcc_emails] || [],
      from_email: expected_output[:from_email] || "",
      attachment_ids: (expected_output[:attachment_ids] || []).map(&:to_s),
      saved_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  # Helpers
  def v2_outbound_payload
    product = (Product.first || create_product)
    email_config = product.primary_email_config
    v2_ticket_params.except(:source, :fr_due_by, :due_by, :status, :responder_id).merge(email_config_id: email_config.id).to_json
  end

  def v1_outbound_payload
    product = (Product.first || create_product)
    email_config = product.primary_email_config
    {
      helpdesk_ticket: v1_ticket_params.except(:fr_due_by, :due_by, :status, :source).merge(source: 10, status: 5, email_config_id: email_config.id, product_id: product.id),
      helpdesk: { tags: "#{Faker::Name.name}, #{Faker::Name.name}" },
      cc_emails: "#{Faker::Internet.email}, #{Faker::Internet.email}"
    }.to_json
  end

  def v1_ticket_payload
    { helpdesk_ticket: v1_ticket_params, helpdesk: { tags: "#{Faker::Name.name}, #{Faker::Name.name}" },
      cc_emails: "#{Faker::Internet.email}, #{Faker::Internet.email}" }.to_json
  end

  def v1_update_ticket_payload
    { helpdesk_ticket: v1_ticket_params.merge(cc_email: { cc_emails: [Faker::Internet.email, Faker::Internet.email], reply_cc: [Faker::Internet.email, Faker::Internet.email], fwd_emails: [] }),
      helpdesk: { tags: "#{Faker::Name.name}, #{Faker::Name.name}" } }.to_json
  end

  def v2_ticket_payload
    v2_ticket_params.to_json
  end

  def v2_ticket_update_payload
    v2_ticket_params.except(:due_by, :fr_due_by, :cc_emails, :email).to_json
  end

  # private
  def v2_ticket_params
    @integrate_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    { email: Faker::Internet.email, cc_emails: [Faker::Internet.email, Faker::Internet.email], description:  Faker::Lorem.paragraph, subject: Faker::Lorem.words(10).join(' '),
      priority: 2, status: 7, type: 'Problem', responder_id: @agent.id, source: 1, tags: [Faker::Name.name, Faker::Name.name],
      due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: @integrate_group.id
    }
  end

  def v1_ticket_params
    { email: Faker::Internet.email, description:  Faker::Lorem.paragraph, subject: Faker::Lorem.words(10).join(' '),
      priority: 2, status: 7, ticket_type: 'Problem', responder_id: @agent.id, source: 1,
      due_by: 14.days.since.iso8601, frDueBy: 1.days.since.iso8601, group_id: Group.find(1).id
    }
  end

  def custom_note_params(ticket, source, private_note = false)
    sample_params = {
      source: ticket.source,
      ticket_id: ticket.id,
      body: Faker::Lorem.paragraph,
      user_id: @agent.id
    }
    sample_params.merge!(private: true) if private_note
    sample_params
  end

  # for ticket split

  def create_normal_reply_for(ticket)
    note = ticket.notes.build(note_params(ticket))
    note.save_note
    note
  end

  def twitter_ticket_and_note
    @account.make_current
    social_related_factories_definition
    #create a twitter ticket
    stream_id = get_twitter_stream_id
    twitter_handle = get_twitter_handle

    tweet = new_tweet({ stream_id: stream_id })
    requester = create_tweet_user(tweet[:user])
    ticket = create_twitter_ticket({
      twitter_handle: twitter_handle,
      tweet: tweet,
      requester: requester
    })
    note_options = {
      tweet: new_tweet({ 
        twitter_user: tweet[:user],
        body: Faker::Lorem.sentence
      }),
      twitter_handle: twitter_handle,
      stream_id: stream_id
    }
    note = twitter_reply_to_ticket(ticket, note_options, false)
    [ticket, note]
  end

  def create_fb_ticket_and_note
    social_related_factories_definition
    options = {}
    options[:fb_page] ||= Account.current.facebook_pages.first || create_fb_page(true)
    options[:post] = fb_post_params
    ticket = create_fb_ticket(options)
    options[:post] = fb_post_params
    note = fb_reply_to_ticket(ticket, options, false)
    [ticket, note]
  end

  def note_params(ticket)
    {
      note_body_attributes: {
        body_html: Faker::Lorem.paragraph
      },
      incoming: true,
      user_id:  ticket.requester.id,
      source: Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter]
    }
  end

  def social_related_factories_definition
    define_social_factories
  rescue
    true
  end

  def verify_split_note_activity(ticket, note)
    ticket_id = ActiveSupport::JSON.decode(response.body)['id']
    new_ticket = @account.tickets.find_by_display_id(ticket_id)
    match_json(ticket_show_pattern(new_ticket))
    refute ticket.notes.find_by_id(note.id).present?
  end

  def add_attachments_to_note(note, count = 1)
    count.times do 
      note.attachments.build(
        content: fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
        description: Faker::Lorem.characters(10),
        account_id: @account.id
      )
      note.cloud_files.build({ filename: "#{Faker::Name.name}.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 })
    end
    note.save
  end

  def verify_attachments_moving(attachment_ids)
    ticket_id = ActiveSupport::JSON.decode(response.body)['id']
    new_ticket = @account.tickets.reload.find_by_display_id(ticket_id)
    assert new_ticket.attachments.map(&:id) == attachment_ids
    assert new_ticket.cloud_files.present?
  end

  def private_api_ticket_index_pattern(survey_results = {}, requester = false, ticket_states = false, company = false)
    pattern_array = Helpdesk::Ticket.last(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]).map do |ticket|
      pattern = index_ticket_pattern_with_associations(ticket, requester, ticket_states, company, [:tags])
      pattern.merge!(requester: Hash) if requester
      pattern.merge!(survey_result: feedback_pattern(survey_results[ticket.id])) if survey_results[ticket.id]
      pattern
    end
  end

  def ticket_show_pattern(ticket, survey_result = nil, requester = false)
    pattern = ticket_pattern(ticket).merge(cloud_files: Array)
    ticket_topic = ticket_topic_pattern(ticket)
    pattern.merge!(freshfone_call: freshfone_call_pattern(ticket)) if freshfone_call_pattern(ticket).present?
    if Account.current.features?(:facebook) && ticket.facebook?
      fb_pattern = ticket.fb_post.post? ? fb_post_pattern({}, ticket.fb_post) : fb_dm_pattern({}, ticket.fb_post)
      pattern.merge!(fb_post: fb_pattern)
    end
    pattern.merge!(tweet: tweet_pattern({}, ticket.tweet)) if Account.current.features?(:twitter) && ticket.twitter?
    pattern.merge!(meta: ticket_meta_pattern(ticket))
    pattern.merge!(survey_result: feedback_pattern(survey_result)) if survey_result
    pattern.merge!(ticket_topic: ticket_topic) if ticket_topic.present?
    pattern.merge!(requester: Hash) if requester
    pattern
  end

  def freshfone_call_pattern(ticket)
    call = ticket.freshfone_call
    return unless call.present? && call.recording_url.present? && call.recording_audio
    {
      id: call.id,
      duration: call.call_duration,
      recording: attachment_pattern(call.recording_audio)
    }
  end

  def ticket_meta_pattern(ticket)
    meta_info = ticket.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["meta"]).body
    meta_info = YAML::load(meta_info)
    handle_timestamps(meta_info)
  end

  def ticket_topic_pattern(ticket)
    topic = ticket.topic
    return unless topic.present?
    {
      id: topic.id,
      title: topic.title
    }
  end

  def handle_timestamps(meta_info)
    if meta_info.is_a?(Hash) && meta_info.keys.include?('time')
      meta_info['time'] = Time.parse(meta_info['time']).utc.iso8601
    end
    meta_info
  end

  def new_fone_call
    if @account.freshfone_account.present?
      @credit = @account.freshfone_credit
      @number ||= @account.freshfone_numbers.first
    else
      create_test_freshfone_account
    end
    @call = create_freshfone_call
    create_audio_attachment
  end

  def create_audio_attachment
    @file_url ||= "#{Rails.root}/spec/fixtures/files/callrecording.mp3"
    @data = File.open(@file_url)

    @call.update_attributes(recording_url: @file_url.gsub('.mp3', ''))
    @call.update_status({ DialCallStatus: 'voicemail' })
    # It's tough to parse audio and get actual duration. So setting a random value.
    @call.call_duration = 25
    
    @call.build_recording_audio(content: @data).save
  end

  def new_ticket_from_call
    new_fone_call
    @ticket = create_ticket
    associate_call_to_item(@ticket)

    new_fone_call
    note = create_normal_reply_for(@ticket)
    associate_call_to_item(note)    
    @ticket
  end

  def new_ticket_from_forum_topic
    topic = create_test_topic(Forum.first)
    ticket = create_ticket
    ticket_topic = create_ticket_topic_mapping(topic, ticket)
    ticket
  end

  def associate_call_to_item(obj)
    @call.notable_id = obj.id
    @call.notable_type = obj.class.name
    @call.save
  end

  def conversations_pattern(ticket, limit = false)
    notes_pattern = ticket.notes.visible.exclude_source('meta').order(:created_at).map do |n|
      note_pattern_index(n)
    end
    limit ? notes_pattern.take(limit) : notes_pattern
  end

  def note_pattern_index(note)
    index_note = {
      from_email: note.from_email,
      cc_emails:  note.cc_emails,
      bcc_emails: note.bcc_emails,
      source: note.source
    }
    single_note = note_pattern({}, note)
    single_note.merge!(index_note)
    single_note.merge!(freshfone_call: freshfone_call_pattern(note)) if freshfone_call_pattern(note)
    single_note
  end

end
