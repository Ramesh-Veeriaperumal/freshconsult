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
  include AttachmentsTestHelper
  include Helpdesk::Email::Constants

  # Patterns
  def deleted_ticket_pattern(expected_output = {}, ticket)
    ticket_pattern(expected_output, ticket).merge(deleted: (expected_output[:deleted] || ticket.deleted).to_s.to_bool)
  end

  def show_deleted_ticket_pattern(expected_output = {}, ticket)
    show_ticket_pattern(expected_output, ticket).merge(deleted: (expected_output[:deleted] || ticket.deleted).to_s.to_bool)
  end

  def index_ticket_pattern(ticket, exclude = [])
    ticket_pattern(ticket).except(*([:attachments, :conversations, :tags] - exclude))
  end

  def so_ticket_pattern(expected_output = {}, ticket)
    ticket_pattern(expected_output, ticket).merge(internal_agent_id:  expected_output[:internal_agent_id] || ticket.internal_agent_id,
                                                  internal_group_id: expected_output[:internal_group_id] || ticket.internal_group_id)
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

  def show_ticket_pattern_with_notes(ticket, limit = false)
    notes_pattern = []
    ticket.notes.visible.exclude_source('meta').order(:created_at).each do |n|
      notes_pattern << index_note_pattern(n)
    end
    notes_pattern = notes_pattern.take(limit) if limit
    show_ticket_pattern(ticket).merge(conversations: notes_pattern.ordered!)
  end

  def ticket_pattern_with_association(ticket, limit = false, notes = true, requester = true, company = true, stats = true)
    result_pattern = ticket_pattern(ticket)
    if notes
      notes_pattern = []
      ticket.notes.visible.exclude_source('meta').order(:created_at).each do |n|
        notes_pattern << index_note_pattern(n)
      end
      notes_pattern = notes_pattern.take(10) if limit
      result_pattern[:conversations] = notes_pattern.ordered!
    end
    result_pattern[:deleted] = true if ticket.deleted
    if requester
      result_pattern[:requester] = ticket.requester ? requester_pattern(ticket.requester) : {}
    end
    if company
      result_pattern[:company] = ticket.company ? company_pattern(ticket.company) : {}
    end
    if stats
      result_pattern[:stats] = ticket.ticket_states ? ticket_states_pattern(ticket.ticket_states, ticket.status) : {}
    end
    result_pattern
  end

  def show_ticket_pattern_with_association(ticket, limit = false, notes = true, requester = true, company = true, stats = true)
    ticket_pattern_with_association(ticket, limit, notes, requester, company, stats).merge(association_type: ticket.association_type)
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

  def ticket_states_pattern(ticket_states, status=nil)
    {
      closed_at: ticket_states.closed_at.try(:utc).try(:iso8601) || ([5].include?(status) ? ticket_states.updated_at.try(:utc).try(:iso8601) : nil),
      resolved_at: ticket_states.resolved_at.try(:utc).try(:iso8601) || ([4,5].include?(status) ? ticket_states.updated_at.try(:utc).try(:iso8601) : nil),
      first_responded_at: ticket_states.first_response_time.try(:utc).try(:iso8601),
      agent_responded_at: ticket_states.agent_responded_at.try(:utc).try(:iso8601),
      requester_responded_at: ticket_states.requester_responded_at.try(:utc).try(:iso8601),
      status_updated_at: ticket_states.status_updated_at.try(:utc).try(:iso8601),
      pending_since: ticket_states.pending_since.try(:utc).try(:iso8601) || ([3].include?(status) ? ticket_states.updated_at.try(:utc).try(:iso8601) : nil),
      reopened_at: ticket_states.opened_at.try(:utc).try(:iso8601)
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
    custom_field = ticket.custom_field_via_mapping.map { |k, v| [TicketDecorator.display_name(k), v.respond_to?(:utc) ? v.strftime('%F') : v] }.to_h
    ticket_custom_field = (custom_field && ignore_extra_keys) ? custom_field.as_json.ignore_extra_keys! : custom_field.as_json
    description_html = format_ticket_html(ticket, expected_output[:description]) if expected_output[:description]

    ticket_hash = {
      cc_emails: expected_output[:cc_emails] || ticket.cc_email && ticket.cc_email[:cc_emails],
      fwd_emails: expected_output[:fwd_emails] || ticket.cc_email && ticket.cc_email[:fwd_emails],
      reply_cc_emails:  expected_output[:reply_cc_emails] || ticket.cc_email && ticket.cc_email[:reply_cc],
      description:  description_html || ticket.description_html,
      description_text:  ticket.description,
      id: expected_output[:display_id] || ticket.display_id,
      fr_escalated:  (expected_output[:fr_escalated] || ticket.fr_escalated).to_s.to_bool,
      is_escalated:  (expected_output[:is_escalated] || ticket.isescalated).to_s.to_bool,
      association_type: expected_output[:association_type] || ticket.association_type,
      associated_tickets_count: expected_output[:associated_tickets_count] || ticket.associated_tickets_count,
      can_be_associated: expected_output[:can_be_associated] || ticket.can_be_associated?,
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
      email_failure_count: ticket.failure_count,
      attachments: Array,
      tags:  expected_output[:tags] || ticket.tag_names,
      custom_fields:  expected_custom_field || ticket_custom_field,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      due_by: expected_output[:due_by].try(:to_time).try(:utc).try(:iso8601) || ticket.due_by.try(:utc).try(:iso8601),
      fr_due_by: expected_output[:fr_due_by].try(:to_time).try(:utc).try(:iso8601) || ticket.frDueBy.try(:utc).try(:iso8601)
    }
    if @account.shared_ownership_enabled?
      ticket_hash.merge!( :internal_group_id => expected_output[:internal_group_id] || ticket.internal_group_id,
                          :internal_agent_id => expected_output[:internal_agent_id] || ticket.internal_agent_id)
    end

    if @private_api
      ticket_hash
    else
      ticket_hash.except(:associated_tickets_count, :association_type, :can_be_associated, :email_failure_count)
    end
  end

  def show_ticket_pattern(expected_output = {}, ticket)
    ticket_pattern(expected_output, ticket).merge(association_type: expected_output[:association_type] || ticket.association_type)
  end

  def create_ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    ticket_pattern(expected_output, ignore_extra_keys, ticket)
  end

  def update_ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    description = expected_output[:description] || ticket.description_html
    ticket_pattern(expected_output, ignore_extra_keys, ticket).merge(description: description)
  end

  def latest_note_response_pattern(note)
    pattern = private_note_pattern({}, note).merge!(user: Hash)
  end

  # draft_exists denotes whether the draft was saved using old UI code
  def reply_draft_pattern(expected_output, draft_exists = false)
    ret_hash = {
      body: expected_output[:body],
      quoted_text: expected_output[:quoted_text],
      cc_emails: expected_output[:cc_emails] || [],
      bcc_emails: expected_output[:bcc_emails] || [],
      from_email: expected_output[:from_email] || '',
      attachments: Array,
      saved_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    if draft_exists
      ret_hash[:from_email] = nil
      ret_hash[:saved_at] = nil
    end
    ret_hash
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
      due_by: 14.days.since.iso8601, fr_due_by: 1.day.since.iso8601, group_id: @integrate_group.id }
  end

  def v1_ticket_params
    { email: Faker::Internet.email, description:  Faker::Lorem.paragraph, subject: Faker::Lorem.words(10).join(' '),
      priority: 2, status: 7, ticket_type: 'Problem', responder_id: @agent.id, source: 1,
      due_by: 14.days.since.iso8601, frDueBy: 1.day.since.iso8601, group_id: Group.find(1).id }
  end

  def custom_note_params(ticket, _source, private_note = false, reply_source = nil)
    sample_params = {
      source: reply_source || ticket.source,
      ticket_id: ticket.id,
      body: Faker::Lorem.paragraph,
      user_id: @agent.id
    }
    sample_params[:private] = true if private_note
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
    # create a twitter ticket
    stream_id = get_twitter_stream_id
    twitter_handle = get_twitter_handle

    tweet = new_tweet(stream_id: stream_id)
    requester = create_tweet_user(tweet[:user])
    ticket = create_twitter_ticket(twitter_handle: twitter_handle,
                                   tweet: tweet,
                                   requester: requester)
    note_options = {
      tweet: new_tweet(twitter_user: tweet[:user],
                       body: Faker::Lorem.sentence),
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
      note.cloud_files.build(filename: "#{Faker::Name.name}.jpg", url: CLOUD_FILE_IMAGE_URL, application_id: 20)
    end
    note.save
  end

  def verify_attachments_moving(attachment_ids)
    ticket_id = ActiveSupport::JSON.decode(response.body)['id']
    new_ticket = @account.tickets.reload.find_by_display_id(ticket_id)
    assert new_ticket.attachments.map(&:id) == attachment_ids
    assert new_ticket.cloud_files.present?
  end

  def failed_emails_note_pattern(ticket_activity_data)
    ticket_activity_data.ticket_data.each do |tkt_data|
      email_failures = JSON.parse(tkt_data.email_failures)
      email_failures = email_failures.reduce Hash.new, :merge
      to_emails = @note.to_emails
      cc_emails = @note.cc_emails
      @to_list = []
      @cc_list = []
      email_failures.each do |email,error|
        failed_email = {"email" => email,"type" => FAILURE_CATEGORY[error.to_i]}
        @to_list.push(failed_email) if to_emails.include?(email)
        @cc_list.push(failed_email) if cc_emails.include?(email)
      end
    end
    result = {to_list: @to_list, cc_list: @cc_list}
    result
  end

  def failed_emails_ticket_pattern(ticket_activity_data)
    ticket_activity_data.ticket_data.each do |tkt_data|
      email_failures = JSON.parse(tkt_data.email_failures)
      email_failures = email_failures.reduce Hash.new, :merge
      to_emails = @ticket.requester.email
      cc_emails = @ticket.cc_email[:cc_emails]
      to_emails = to_emails.to_a
      @to_list = []
      @cc_list = []
      email_failures.each do |email,error|
        failed_email = {"email" => email,"type" => FAILURE_CATEGORY[error.to_i]}
        @to_list.push(failed_email) if to_emails.include?(email)
        @cc_list.push(failed_email) if cc_emails.include?(email)
      end
    end
    result = {to_list: @to_list, cc_list: @cc_list}
    result
  end

  def private_api_ticket_index_pattern(survey = false, requester = false, company = false, order_by = 'created_at', order_type = 'desc', all_tickets = false)
    filter_clause = all_tickets ? ['spam = ? AND deleted = ?', false, false] : ['created_at > ?', 30.days.ago]

    preload_options = [:tags, :ticket_states, :ticket_old_body, :schema_less_ticket, :flexifield]
    preload_options << :requester if requester
    preload_options << :company if company

    pattern_array = Helpdesk::Ticket.where(*filter_clause).order("#{order_by} #{order_type}").limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]).preload(preload_options).map do |ticket|
      pattern = index_ticket_pattern_with_associations(ticket, requester, true, false, [:tags])
      pattern[:requester] = Hash if requester
      pattern[:company] = Hash if company && ticket.company
      pattern[:survey_result] = feedback_pattern(ticket.custom_survey_results.last) if survey && ticket.custom_survey_results.present?
      pattern
    end
  end

  def private_api_ticket_index_spam_deleted_pattern(spam = false, deleted = false)
    filter_clause = { helpdesk_schema_less_tickets: { boolean_tc02: false }, deleted: deleted }
    filter_clause[:spam] = spam if spam
    pattern_array = Helpdesk::Ticket.joins(:schema_less_ticket).where(filter_clause).order('created_at desc').limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]).map do |ticket|
      index_ticket_pattern_with_associations(ticket, false, true, false, [:tags])
    end
  end

  def private_api_ticket_index_query_hash_pattern(query_hash, wf_order = 'created_at')
    per_page = ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]
    query_hash_params = {}
    query_hash_params[:query_hash] = query_hash
    query_hash_params[:wf_model] = 'Helpdesk::Ticket'
    query_hash_params[:wf_order] = wf_order
    query_hash_params[:data_hash] = QueryHash.new(query_hash_params[:query_hash].values).to_system_format
    pattern_array = Account.current.tickets.filter(params: query_hash_params, filter: 'Helpdesk::Filters::CustomTicketFilter').first(per_page).map do |ticket|
      index_ticket_pattern_with_associations(ticket, false, true, false, [:tags])
    end
  end

  def private_api_ticket_index_filter_pattern(filter_data)
    per_page = ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]
    pattern_array = Account.current.tickets.filter(params: filter_data, filter: 'Helpdesk::Filters::CustomTicketFilter').first(per_page).map do |ticket|
      index_ticket_pattern_with_associations(ticket, false, true, false, [:tags])
    end
  end

  def ticket_show_pattern(ticket, survey_result = nil, requester = false)
    pattern = ticket_pattern_with_association(ticket, false, false, false, false, true).merge(cloud_files: Array)
    ticket_topic = ticket_topic_pattern(ticket)
    pattern[:freshfone_call] = freshfone_call_pattern(ticket) if freshfone_call_pattern(ticket).present?
    if (Account.current.features?(:facebook) || Account.current.basic_facebook_enabled?) && ticket.facebook?
      fb_pattern = ticket.fb_post.post? ? fb_post_pattern({}, ticket.fb_post) : fb_dm_pattern({}, ticket.fb_post)
      pattern[:fb_post] = fb_pattern
    end
    pattern[:tweet] = tweet_pattern({}, ticket.tweet) if (Account.current.features?(:twitter) || Account.current.basic_twitter_enabled?) && ticket.twitter?
    pattern[:meta] = ticket_meta_pattern(ticket)
    pattern[:survey_result] = feedback_pattern(survey_result) if survey_result
    pattern[:ticket_topic] = ticket_topic if ticket_topic.present?
    pattern[:association_type] = ticket.association_type
    pattern[:requester] = Hash if requester
    pattern[:collaboration] = collaboration_pattern if @account.collaboration_enabled?
    pattern
  end

  def bg_worker_update_pattern(params)
    custom_fields_hash = {}
    params[:custom_fields].each { |key, val| custom_fields_hash["#{key}_#{@account.id}".to_sym] = val }
    {
      description: params[:description],
      subject: params[:subject],
      priority: params[:priority],
      status: params[:status],
      ticket_type: params[:type],
      responder_id: params[:responder_id],
      due_by: params[:due_by],
      frDueBy: params[:fr_due_by],
      group_id: params[:group_id],
      custom_field: custom_fields_hash
    }
  end

  def prime_association_pattern(ticket)
    prime_association = ticket.related_ticket? ? ticket.associated_prime_ticket('related') : ticket.associated_prime_ticket('child')
    return unless prime_association.present?
    {
      id: prime_association.display_id,
      requester_id: prime_association.requester_id,
      responder_id: prime_association.responder_id,
      subject: prime_association.subject,
      association_type: prime_association.association_type,
      status: prime_association.status,
      created_at: prime_association.created_at.try(:utc),
      stats: ticket_states_pattern(prime_association.ticket_states, prime_association.status),
      permission: User.current.has_ticket_permission?(prime_association)
    }
  end

  def latest_broadcast_pattern(tracker_id)
    last_broadcast = Helpdesk::BroadcastMessage.where(tracker_display_id: tracker_id).last
    return {} unless last_broadcast.present?
    {
      broadcast_message: {
        body: last_broadcast.body_html,
        created_at: last_broadcast.created_at
      }
    }
  end

  def associations_pattern(ticket)
    associations = ticket.tracker_ticket? ? ticket.associated_subsidiary_tickets('tracker') : ticket.associated_subsidiary_tickets('assoc_parent')
    return unless associations.present?
    responses = associations.map do |item|
      response_hash = {
        group_id: item.group_id,
        priority: item.priority,
        requester_id: item.requester_id,
        responder_id: item.responder_id,
        source: item.source,
        company_id: item.company_id,
        status: item.status,
        permission: User.current.has_ticket_permission?(item),
        stats: ticket_states_pattern(item.ticket_states, item.status),
        subject: item.subject,
        product_id: item.schema_less_ticket.try(:product_id),
        id: item.display_id,
        type: item.ticket_type,
        due_by: item.due_by.try(:utc),
        fr_due_by: item.frDueBy.try(:utc),
        is_escalated: item.isescalated,
        created_at: item.created_at.try(:utc),
        updated_at: item.updated_at.try(:utc),
        email_failure_count: item.schema_less_ticket.failure_count
      }
      response_hash[:deleted] = item.deleted if item.deleted
      response_hash
    end
    responses
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
    meta_info = ticket.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta']).body
    meta_info = YAML.load(meta_info)
    handle_timestamps(meta_info)
  rescue
    {}
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
    @call.update_status(DialCallStatus: 'voicemail')
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
    @account.launch(:forum_post_spam_whitelist)
    topic = create_test_topic(Forum.first)
    @account.rollback(:forum_post_spam_whitelist)
    ticket = create_ticket
    ticket_topic = create_ticket_topic_mapping(topic, ticket)
    ticket
  end

  def associate_call_to_item(obj)
    @call.notable_id = obj.id
    @call.notable_type = obj.class.name
    @call.save
  end

  def conversations_pattern(ticket, requester = false, limit = false)
    notes_pattern = ticket.notes.visible.exclude_source('meta').order(:created_at).map do |n|
      note_pattern = note_pattern_index(n)
      note_pattern[:requester] = Hash if requester
      note_pattern
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
    single_note = private_note_pattern({}, note)
    single_note.merge!(index_note)
    single_note[:freshfone_call] = freshfone_call_pattern(note) if freshfone_call_pattern(note)
    single_note
  end
  
  def create_parent_child_tickets
    @parent_ticket = create_parent_ticket
    @child_ticket  = create_ticket(assoc_parent_id: @parent_ticket.display_id)
  end

  def create_ticket_with_attachments(min = 0, max = 1)
    ticket = create_ticket
    rand(min..max).times do
      ticket.attachments << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id)
    end
    ticket.save
    ticket
  end

  def create_parent_ticket
    create_ticket
    parent_ticket = Helpdesk::Ticket.last
    parent_ticket.update_attributes(association_type: 1)
    parent_ticket
  end

  def create_tracker_ticket
    create_ticket
    tracker_ticket = Helpdesk::Ticket.last
    tracker_ticket.update_attributes(association_type: 3)
    tracker_ticket
  end

    def create_related_tickets(related_count = 1)
    related_count.times.collect {|i| 
      related_ticket = create_ticket
      related_ticket.update_attributes(association_type: 4)
      related_ticket
    }
  end

  def assert_link_failure(ticket_id, pattern = nil)
    assert_response 400
    match_json([bad_request_error_pattern(*pattern)]) if pattern.present?
    if ticket_id.present?
      ticket = Helpdesk::Ticket.find_by_display_id(ticket_id)
      assert !ticket.related_ticket?
    end
  end

  def create_linked_tickets
    @ticket_id = create_ticket.display_id
    @tracker_id = create_tracker_ticket.display_id
    link_to_tracker(@tracker_id, @ticket_id)
  end

  def link_to_tracker(tracker_id, ticket_id)
    put :link, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
  end

  def assert_unlink_failure(ticket_id, error_code, pattern = nil)
    assert_response error_code
    match_json([bad_request_error_pattern(*pattern)]) if pattern.present?
    if ticket_id.present?
      ticket = Helpdesk::Ticket.where(display_id: ticket_id).first
      assert ticket.related_ticket?
    end
  end

  def collaboration_pattern
    { convo_token: wildcard_matcher }
  end
end
