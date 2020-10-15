['ticket_fields_test_helper.rb', 'conversations_test_helper.rb', 'attachments_test_helper.rb', 'users_test_helper'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['ticket_helper.rb', 'company_helper.rb', 'group_helper.rb', 'note_helper.rb', 'email_configs_helper.rb', 'products_helper.rb', 'freshcaller_spec_helper.rb', 'forum_helper.rb', 'agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require "#{Rails.root}/spec/helpers/social_tickets_helper.rb"
module ApiTicketsTestHelper
  include GroupHelper
  include AgentHelper
  include ConversationsTestHelper
  include TicketFieldsTestHelper
  include EmailConfigsHelper
  include ProductsHelper
  include CompanyHelper
  include TicketHelper
  include NoteHelper
  include SocialTicketsHelper
  include FreshcallerSpecHelper
  include ForumHelper
  include AdvancedTicketScopes
  include AttachmentsTestHelper
  include UsersTestHelper
  include Helpdesk::Email::Constants
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  include Crypto::TokenHashing

  CUSTOM_FIELDS_CHOICES = Faker::Lorem.words(5).uniq.freeze
  DROPDOWN_OPTIONS = Faker::Lorem.words(5).freeze
  CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date).freeze
  DEPENDENT_FIELD_VALUES = {
    Faker::Address.country => {
      Faker::Address.state => [Faker::Address.city],
      Faker::Address.state => [Faker::Address.city]
    },
    Faker::Address.country => {
      Faker::Address.state => [Faker::Address.city],
      Faker::Address.state => [Faker::Address.city],
      Faker::Address.state => [Faker::Address.city, Faker::Address.city]
    }
  }.freeze
  TAG_NAMES = Faker::Lorem.words(10).freeze
  CUSTOM_FIELDS_VALUES = { 'country' => 'USA', 'state' => 'California', 'city' => 'Burlingame', 'number' => 32_234, 'decimal' => '90.89', 'checkbox' => true, 'text' => Faker::Name.name, 'paragraph' => Faker::Lorem.paragraph, 'dropdown' => CUSTOM_FIELDS_CHOICES[0], 'date' => '2015-09-09' }.freeze
  PRIVATE_KEY_STRING = OpenSSL::PKey::RSA.new(File.read('config/cert/jwe_decryption_key.pem'), 'securefield')
  DEFAULT_TICKET_FILTER = :all_tickets.to_s.freeze
  NOTE_ANCESTRY = '%{ticket_fb_post_id}/%{note_fb_post_id}'.freeze


  # pattern
  def sla_policy_pattern(expected_output = {}, sla_policy)
    conditions_hash = {}
    sla_policy.conditions.each { |key, value| conditions_hash[key.to_s.pluralize] = value } unless sla_policy.conditions.nil?
    {
      id: Fixnum,
      name: sla_policy.name,
      description: sla_policy.description,
      is_default: sla_policy.is_default,
      applicable_to: expected_output[:applicable_to] || conditions_hash,
      position: sla_policy.position,
      active: sla_policy.active,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def tickets_controller_before_all before_all_run
    return if before_all_run
    @account.features.forums.create
    @account.ticket_fields.custom_fields.each(&:destroy)
    @account.tickets.destroy_all
    Helpdesk::TicketStatus.find_by_status_id(2).update_column(:stop_sla_timer, false)
    @@ticket_fields = []
    @@custom_field_names = []
    @@ticket_fields << create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', CUSTOM_FIELDS_CHOICES)
    @@choices_custom_field_names = @@ticket_fields.map(&:name)
    CUSTOM_FIELDS.each do |custom_field|
      next if %w(dropdown country state city).include?(custom_field)
      @@ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
      @@custom_field_names << @@ticket_fields.last.name
    end
    create_skill if @account.skills.empty?

    @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', DROPDOWN_OPTIONS)
    10.times.each do |i|
      create_product
    end
    10.times.each do |i|
      create_company
    end
    10.times.each do |i|
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    10.times.each do |i|
      create_group_with_agents(@account, agent_list: [@account.agents.sample.user_id])
    end

    50.times.each do |i|
       country = DEPENDENT_FIELD_VALUES.keys.sample
       state   = DEPENDENT_FIELD_VALUES[country].keys.sample
       city    = DEPENDENT_FIELD_VALUES[country][state].sample
       params = ticket_params_hash.except(:description).merge(custom_field: {})
       params[:custom_field]["test_custom_dropdown_#{@account.id}"] = [DROPDOWN_OPTIONS.sample].sample
       params[:custom_field]["test_custom_country_#{@account.id}"]  = country
       params[:custom_field]["test_custom_state_#{@account.id}"]    = state
       params[:custom_field]["test_custom_city_#{@account.id}"]     = city
       params[:tag_names] = [TAG_NAMES.sample(rand(1..6)).uniq.join(',')].sample
       params[:responder_id] = [@account.agents.sample.id, nil].sample
       ticket = create_ticket(params)
       ticket.product = [@account.products.sample, nil].sample
       requester = [ticket.requester, nil].sample
       company_id = [@account.companies.sample.id, nil].sample
       requester.user_companies.create(company_id: company_id) if requester && company_id
       ticket.company_id = company_id
       ticket.save
    end

    enable_feature(:field_service_management) do
      perform_fsm_operations
      parent_ticket = create_ticket
      create_service_task_ticket(assoc_parent_id: parent_ticket.display_id)
      create_service_task_ticket(assoc_parent_id: parent_ticket.display_id)
      parent_ticket = create_ticket
      10.times.each do |i|
        params = { assoc_parent_id: parent_ticket.display_id, fsm_contact_name: Faker::Name.name,
                   fsm_phone_number: Faker::Number.number(10), fsm_service_location: Faker::Address.city,
                   fsm_appointment_start_time: Time.zone.now.advance(days: i * 2 - 10).strftime('%Y-%m-%dT%H:%m:%SZ'),
                   fsm_appointment_end_time: (Time.zone.now.advance(days: i * 2 - 10) + rand(20..60).minutes).strftime('%Y-%m-%dT%H:%m:%SZ') }
        create_service_task_ticket(params)
      end
    end
  end

  # Patterns
  def deleted_ticket_pattern(expected_output = {}, ticket)
    ticket_pattern(expected_output, ticket).merge(deleted: (expected_output[:deleted] || ticket.deleted).to_s.to_bool)
  end

  def show_deleted_ticket_pattern(expected_output = {}, ticket)
    show_ticket_pattern(expected_output, ticket).merge(deleted: (expected_output[:deleted] || ticket.deleted).to_s.to_bool)
  end

  def index_ticket_pattern(ticket, exclude = [])
    ticket_pattern(ticket).merge(ticket_association_pattern(ticket,true)).except(*([:attachments, :conversations, :description, :description_text] - exclude))
  end

  def so_ticket_pattern(expected_output = {}, ticket)
    ticket_pattern(expected_output, ticket).merge(internal_agent_id:  expected_output[:internal_agent_id] || ticket.internal_agent_id,
                                                  internal_group_id: expected_output[:internal_group_id] || ticket.internal_group_id)
  end

  def index_ticket_pattern_with_associations(ticket, param_object, exclude = [])
    ticket_pattern_with_association(
      ticket,
      param_object
      ).merge(ticket_association_pattern(ticket,true)).except(*([:attachments, :conversations, :description, :description_text] - exclude))
  end

  def index_deleted_ticket_pattern(ticket, exclude = [])
    index_ticket_pattern(ticket, exclude).merge(deleted: ticket.deleted.to_s.to_bool)
  end

  def ticket_pattern_with_notes(ticket, limit = false)
    notes_pattern = []
    ticket.notes.visible.exclude_source('meta').order(:created_at).each do |n|
      notes_pattern << index_note_pattern(n)
    end
    notes_pattern = notes_pattern.take(limit) if limit
    ticket_pattern(ticket).merge(conversations: notes_pattern.ordered!)
  end

  def ticket_pattern_with_association(ticket, param_object)
    result_pattern = ticket_pattern(ticket)
    if param_object.notes
      notes_pattern = []
      ticket.notes.visible.exclude_source('meta').order(:created_at).each do |n|
        notes_pattern << index_note_pattern(n)
      end
      notes_pattern = notes_pattern.take(10) if param_object.limit
      result_pattern[:conversations] = notes_pattern.ordered!
    end
    result_pattern[:deleted] = true if ticket.deleted
    if param_object.requester
      result_pattern[:requester] = ticket.requester ? requester_pattern(ticket.requester) : {}
    end
    if param_object.company
      result_pattern[:company] = ticket.company ? company_pattern(ticket.company) : {}
    end
    if param_object.stats
      result_pattern[:stats] = ticket.ticket_states ? ticket_states_pattern(ticket.ticket_states, ticket.status) : {}
    end
    if param_object.sla_policy
      result_pattern[:sla_policy] = ticket.sla_policy ? sla_policy_pattern(ticket.sla_policy) : {}
    end
    result_pattern
  end

  def show_ticket_pattern_with_association(ticket, param_object)
    ticket_pattern_with_association(ticket, param_object).merge(association_type: ticket.association_type, source_additional_info: source_additional_info(ticket))
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
    states_hash = {
      closed_at: ticket_states.closed_at.try(:utc).try(:iso8601) || ([5].include?(status) ? ticket_states.updated_at.try(:utc).try(:iso8601) : nil),
      resolved_at: ticket_states.resolved_at.try(:utc).try(:iso8601) || ([4,5].include?(status) ? ticket_states.updated_at.try(:utc).try(:iso8601) : nil),
      first_responded_at: ticket_states.first_response_time.try(:utc).try(:iso8601),
      agent_responded_at: ticket_states.agent_responded_at.try(:utc).try(:iso8601),
      requester_responded_at: ticket_states.requester_responded_at.try(:utc).try(:iso8601),
      status_updated_at: ticket_states.status_updated_at.try(:utc).try(:iso8601),
      pending_since: ticket_states.pending_since.try(:utc).try(:iso8601) || ([3].include?(status) ? ticket_states.updated_at.try(:utc).try(:iso8601) : nil),
      reopened_at: ticket_states.opened_at.try(:utc).try(:iso8601)
    }
    if @channel_v2_api
      states_hash.merge!({
        first_assigned_at: ticket_states.first_assigned_at.try(:utc).try(:iso8601),
        assigned_at: ticket_states.assigned_at.try(:utc).try(:iso8601),
        sla_timer_stopped_at: ticket_states.sla_timer_stopped_at.try(:utc).try(:iso8601),
        avg_response_time_by_bhrs: ticket_states.avg_response_time_by_bhrs,
        resolution_time_by_bhrs: ticket_states.resolution_time_by_bhrs,
        on_state_time: ticket_states.on_state_time,
        inbound_count: ticket_states.inbound_count,
        outbound_count: ticket_states.outbound_count,
        group_escalated: ticket_states.group_escalated,
        first_resp_time_by_bhrs: ticket_states.first_resp_time_by_bhrs,
        avg_response_time: ticket_states.avg_response_time,
        resolution_time_updated_at: ticket_states.resolution_time_updated_at.try(:utc).try(:iso8601)
      })
    end
    states_hash
  end

  def show_deleted_ticket_pattern(expected_output = {}, ticket)
    show_ticket_pattern(expected_output, ticket).merge(deleted: (expected_output[:deleted] || ticket.deleted).to_s.to_bool)
  end

  def show_ticket_pattern_with_notes(ticket, limit = false)
    notes_pattern = []
    ticket.notes.visible.exclude_source('meta').order(:created_at).each do |n|
      notes_pattern << index_note_pattern(n)
    end
    notes_pattern = notes_pattern.take(limit) if limit
    show_ticket_pattern(ticket).merge(conversations: notes_pattern.ordered!)
  end

  def feedback_pattern(survey_result)
    {
      survey_id: survey_result.survey_id,
      agent_id: survey_result.agent_id,
      group_id: survey_result.group_id,
      rating: survey_result.custom_ratings
    }
  end

  def date_diplay_format(type, date)
    @name_type_mapping ||= Account.current.ticket_fields_name_type_mapping_cache
    @name_type_mapping[type] == Helpdesk::TicketField::CUSTOM_DATE_TIME ? date.strftime('%Y-%m-%dT%H:%m:%SZ') : date.strftime('%F')
  end

  def ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    expected_custom_field = (expected_output[:custom_fields] && ignore_extra_keys) ? expected_output[:custom_fields].ignore_extra_keys! : expected_output[:custom_fields]
    custom_field = ticket.custom_field_via_mapping.map { |k, v| [TicketDecorator.display_name(k), v.respond_to?(:utc) ? date_diplay_format(k, v) : v] }.to_h
    ticket_custom_field = (custom_field && ignore_extra_keys) ? custom_field.as_json.ignore_extra_keys! : custom_field.as_json
    description_html = format_ticket_html(expected_output[:description]) if expected_output[:description]

    ticket_hash = {
      cc_emails: expected_output[:cc_emails] || ticket.cc_email && ticket.cc_email[:cc_emails],
      fwd_emails: expected_output[:fwd_emails] || ticket.cc_email && ticket.cc_email[:fwd_emails],
      reply_cc_emails:  expected_output[:reply_cc_emails] || ticket.cc_email && ticket.cc_email[:reply_cc],
      ticket_cc_emails:  expected_output[:ticket_cc_emails] || ticket.cc_email && ticket.cc_email[:tkt_cc],
      description: description_html || description_info(ticket)[:description],
      description_text: description_info(ticket)[:description_text],
      id: expected_output[:display_id] || ticket.display_id,
      fr_escalated:  (expected_output[:fr_escalated] || ticket.fr_escalated).to_s.to_bool,
      is_escalated:  (expected_output[:is_escalated] || ticket.isescalated).to_s.to_bool,
      association_type: expected_output[:association_type] || ticket.association_type,
      associated_tickets_count: expected_output[:associated_tickets_count] || ticket.subsidiary_tkts_count,
      can_be_associated: expected_output[:can_be_associated] || ticket.can_be_associated?,
      spam:  (expected_output[:spam] || ticket.spam).to_s.to_bool,
      email_config_id:  expected_output[:email_config_id] || ticket.email_config_id,
      group_id:  expected_output[:group_id] || ticket.group_id,
      priority:  expected_output[:priority] || ticket.priority,
      requester_id:  expected_output[:requester_id] || ticket.requester_id,
      responder_id:  expected_output[:responder_id] || ticket.responder_id,
      source: expected_output[:source] || ticket.source,
      status: expected_output[:status] || ticket.status,
      subject: expected_output[:subject] || subject_info(ticket),
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
    if Account.current.advanced_ticket_scopes_enabled? 
      ticket_hash[:write_access] = User.current.present? ? agent_has_write_access?(ticket, User.current.associated_group_ids) : true
    end
    if @account.shared_ownership_enabled?
      ticket_hash.merge!( :internal_group_id => expected_output[:internal_group_id] || ticket.internal_group_id,
                          :internal_agent_id => expected_output[:internal_agent_id] || ticket.internal_agent_id)
    end

    if @account.skill_based_round_robin_enabled?
      ticket_hash.merge!( :skill_id => expected_output[:skill_id] || ticket.skill_id)
    end

    if @channel_v2_api
      ticket_hash.merge!(
        import_id: ticket.import_id,
        ticket_id: ticket.id,
        deleted: ticket.deleted,
        stats: ticket_states_pattern(ticket.ticket_states, ticket.status)
      )
    end

    if @account.next_response_sla_enabled?
      ticket_hash.merge!( nr_due_by: ticket.nr_due_by.try(:utc).try(:iso8601),
                          nr_escalated: ticket.nr_escalated.to_s.to_bool )
    end

    if @private_api
      ticket_hash
    else
      ticket_hash.except(:skill_id, :associated_tickets_count, :association_type, :can_be_associated, :email_failure_count)
    end
  end

  def description_info(ticket)
    return default_twitter_description(ticket) if restrict_twitter_ticket_content?(ticket)

    {
      description: ticket.description_html,
      description_text: ticket.description
    }
  end

  def default_twitter_description(ticket)
    tweet_type = ticket.tweet.tweet_type.to_sym
    {
      description: Social::Twitter::Constants::DEFAULT_TWITTER_CONTENT_HTML[tweet_type],
      description_text: Social::Twitter::Constants::DEFAULT_TWITTER_CONTENT[tweet_type]
    }
  end

  def subject_info(ticket)
    restrict_twitter_ticket_content?(ticket) ? Social::Twitter::Constants::DEFAULT_TWITTER_CONTENT[ticket.tweet.tweet_type.to_sym] : ticket.subject
  end

  def twitter_ticket?(ticket)
    ticket.source == Helpdesk::Source::TWITTER && ticket.tweet
  end

  def restrict_twitter_ticket_content?(ticket)
    Account.current.twitter_api_compliance_enabled? && twitter_ticket?(ticket) && public_v2_api?
  end

  def public_v2_api?
    CustomRequestStore.read(:api_v2_request)
  end

  def latest_note_as_ticket_pattern(expected_output = {}, ticket)
    description_html = format_ticket_html(expected_output[:description]) if expected_output[:description]
    ret_hash = {
      description: description_html || description_info(ticket)[:description],
      description_text: description_info(ticket)[:description_text],
      id: expected_output[:display_id] || ticket.display_id,
    }
  end

  def show_ticket_pattern(expected_output = {}, ticket)
    ticket_pattern(expected_output, ticket).merge(association_type: expected_output[:association_type] || ticket.association_type, source_additional_info: source_additional_info(ticket))
  end

  def create_ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    ticket_pattern(expected_output, ignore_extra_keys, ticket)
  end

  def update_ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    description = expected_output[:description] || description_info(ticket)[:description]
    update_ticket_pattern = ticket_pattern(expected_output, ignore_extra_keys, ticket).merge(description: description)
    update_ticket_pattern.merge!(ticket_association_pattern(ticket)) if ticket.associated_ticket?
    update_ticket_pattern
  end

  def latest_note_response_pattern(note)
    pattern = private_note_pattern({}, note).merge!(user: Hash)
  end

  def ticket_association_pattern(ticket, associated_tickets_count = false)
    response = { association_type: ticket.association_type }
    associated_tickets_count ? response.merge( associated_tickets_count: ticket.subsidiary_tkts_count )
                             : response.merge( associated_tickets_list: ticket.associates )
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
      inline_attachment_ids: Array,
      articles_suggested: expected_output[:articles_suggested] || [],
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

  def count_es_response(t_id1, t_id2 = nil)
    response = {
      took: 5,
      timed_out: false,
      _shards:
      {
        total: 1,
        successful: 1,
        failed: 0
      },
      hits:
      {
        total: 2,
        max_score: nil,
        hits:
        [
          {
            _index: 'es_filters_count',
            _type: 'ticket',
            _id: t_id1,
            _score: nil,
            _routing: '1',
            sort: [1522824906000]
          }
        ]
      }
    }
    if t_id2
      obj = {
        _index: 'es_filters_count',
        _type: 'ticket',
        _id: t_id2,
        _score: nil,
        _routing: '1',
        sort: [1522746234000]
      }
      response[:hits][:hits].push(obj)
    end
    response
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
      source: Helpdesk::Source::TWITTER
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
      email_failures.each do |email, error|
        failed_email = { 'email' => email, 'type' => FAILURE_CATEGORY[error.to_i] }
        @to_list.push(failed_email) if to_emails.include?(email)
        @cc_list.push(failed_email) if cc_emails.include?(email)
      end
    end
    result = { to_list: @to_list, cc_list: @cc_list }
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
        failed_email = { 'email' => email, 'type' => FAILURE_CATEGORY[error.to_i] }
        @to_list.push(failed_email) if to_emails.include?(email)
        @cc_list.push(failed_email) if cc_emails.include?(email)
      end
    end
    result = { to_list: @to_list, cc_list: @cc_list }
    result
  end

  def filter_factory_order_response_stub(order_by = 'created_at', order_type = 'desc', all_tickets = false)
    filter_clause = ['spam = ? AND deleted = ?', false, false]
    unless all_tickets
      filter_clause[0] << ' AND created_at > ?'
      filter_clause << Time.zone.now.beginning_of_day.ago(1.month).utc
    end
    ticket_ids = Helpdesk::Ticket.where(*filter_clause)
                                 .permissible(User.current)
                                 .order("#{order_by} #{order_type}")
                                 .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
                                 .map(&:id)
    {
      total: [31, ticket_ids.count].min,
      results: ticket_ids.map { |id| { id: id, document: 'ticketanalytics' } }
    }.to_json
  end

  def public_api_filter_factory_order_response_stub(order_by = 'created_at', order_type = 'desc', all_tickets = false)
    filter_clause = ['spam = ? AND deleted = ?', false, false]
    unless all_tickets
      filter_clause[0] << ' AND created_at > ?'
      filter_clause << Time.zone.now.beginning_of_day.ago(1.month).utc
    end
    param_object = OpenStruct.new
    ticket_ids = Helpdesk::Ticket.where(*filter_clause).permissible(User.current)
                                 .order("#{order_by} #{order_type}")
                                 .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
                                 .map(&:id)
    {
      total: 31,
      results: ticket_ids.map { |id| { id: id, document: 'ticketanalytics' } }
    }.to_json
  end

  def private_api_ticket_index_pattern(survey = false, requester = false, company = false, order_by = 'created_at', order_type = 'desc', all_tickets = false, exclude_options = [])
    filter_clause = ['spam = ? AND deleted = ?', false, false]
    excludable_fields = ApiTicketConstants::EXCLUDABLE_FIELDS
    unless all_tickets
      filter_clause[0] << ' AND created_at > ?'
      filter_clause << Time.zone.now.beginning_of_day.ago(1.month).utc
    end

    preload_options = [:tags, :ticket_states, :ticket_body, :schema_less_ticket, :flexifield]
    preload_options << :requester if requester
    preload_options << :company if company
    pattern_array = Helpdesk::Ticket.where(*filter_clause).permissible(User.current).order("#{order_by} #{order_type}").limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]).preload(preload_options).map do |ticket|
      param_object = OpenStruct.new(requester: requester, stats: true)
      pattern = index_ticket_pattern_with_associations(ticket, param_object, [:tags])
      pattern[:requester] = Hash if requester
      pattern[:company] = Hash if company && ticket.company
      pattern[:survey_result] = feedback_pattern(ticket.custom_survey_results.last) if survey && ticket.custom_survey_results.present?
      exclude_options.each do |exclude|
        pattern.delete(exclude.to_sym) if excludable_fields.include?(exclude)
      end
      pattern
    end
  end

  def public_api_ticket_index_pattern(survey = false, requester = false, company = false, order_by = 'created_at', order_type = 'desc', all_tickets = false, exclude_options = [])
    filter_clause = ['spam = ? AND deleted = ?', false, false]
    excludable_fields = ApiTicketConstants::EXCLUDABLE_FIELDS
    unless all_tickets
      filter_clause[0] << ' AND created_at > ?'
      filter_clause << Time.zone.now.beginning_of_day.ago(1.month).utc
    end

    preload_options = [:tags, :ticket_states, :ticket_body, :schema_less_ticket, :flexifield]
    preload_options << :requester if requester
    preload_options << :company if company
    pattern_array = Helpdesk::Ticket.where(*filter_clause).permissible(User.current).order("#{order_by} #{order_type}").limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]).preload(preload_options).map do |ticket|
      param_object = OpenStruct.new
      pattern = index_ticket_pattern_with_associations(ticket, param_object, [:tags])
      pattern[:requester] = Hash if requester
      pattern[:company] = Hash if company && ticket.company
      pattern[:survey_result] = feedback_pattern(ticket.custom_survey_results.last) if survey && ticket.custom_survey_results.present?
      exclude_options.each do |exclude|
        pattern.delete(exclude.to_sym) if excludable_fields.include?(exclude)
      end
      pattern
    end
  end

  def private_api_ticket_index_spam_deleted_pattern(spam = false, deleted = false)
    filter_clause = { helpdesk_schema_less_tickets: { boolean_tc02: false }, deleted: deleted }
    filter_clause[:spam] = spam if spam
    param_object = OpenStruct.new(stats: true)
    pattern_array = Helpdesk::Ticket.joins(:schema_less_ticket).where(filter_clause).order('created_at desc').limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]).map do |ticket|
      index_ticket_pattern_with_associations(ticket, param_object, [:tags])
    end
  end

  def private_api_ticket_index_query_hash_pattern(query_hash, wf_order = 'created_at', order_type = 'desc')
    query_hash_params = {}
    query_hash_params[:query_hash] = query_hash
    query_hash_params[:wf_model] = 'Helpdesk::Ticket'
    query_hash_params[:wf_order] = wf_order
    query_hash_params[:wf_order_type] = order_type
    query_hash_params[:data_hash] = QueryHash.new(query_hash_params[:query_hash].values).to_system_format
    param_object = OpenStruct.new(stats: true)
    pattern_array = private_api_ticket_index_first_page_objects(query_hash_params).map do |ticket|
      index_ticket_pattern_with_associations(ticket, param_object, [:tags])
    end
  end

  def public_api_ticket_index_query_hash_pattern(query_hash, wf_order = 'created_at', order_type = 'desc')
    query_hash_params = {}
    query_hash_params[:wf_model] = 'Helpdesk::Ticket'
    query_hash_params[:wf_order] = wf_order
    query_hash_params[:wf_order_type] = order_type
    query_hash_params[:data_hash] = d_query_hash(query_hash)
    query_hash_params[:per_page] = query_hash[:per_page] if query_hash[:per_page]
    stats = query_hash[:include] == 'stats'
    requester = query_hash[:include] == 'requester'
    description = query_hash[:include] == 'description'
    param_object = OpenStruct.new(stats: stats, requester: requester, description: description)
    pattern_array = private_api_ticket_index_first_page_objects(query_hash_params).map do |ticket|
      index_ticket_pattern_with_associations(ticket, param_object, [:tags])
    end
  end

  def private_api_ticket_index_raw_query_pattern(sql_query)
    per_page = ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]
    param_object = OpenStruct.new(stats: true)

    Account.current.tickets.where(sql_query).order('created_at desc').first(per_page).map do |ticket|
      index_ticket_pattern_with_associations(ticket, param_object, [:tags])
    end
  end

  def private_api_ticket_index_first_page_objects(query_hash_params)
    per_page = query_hash_params[:per_page] ? query_hash_params[:per_page] : ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]
    Account.current.tickets.filter(params: query_hash_params, filter: 'Helpdesk::Filters::CustomTicketFilter').first(per_page)
  end

  def filter_factory_es_cluster_query_response_stub(query_hash, wf_order = 'created_at')
    query_hash_params = {}
    query_hash_params[:query_hash] = query_hash
    query_hash_params[:wf_model] = 'Helpdesk::Ticket'
    query_hash_params[:wf_order] = wf_order
    query_hash_params[:data_hash] = QueryHash.new(query_hash_params[:query_hash].values).to_system_format
    param_object = OpenStruct.new(stats: true)

    ticket_ids = private_api_ticket_index_first_page_objects(query_hash_params).map(&:id)
    {
      total: 31,
      results: ticket_ids.map { |id| { id: id, document: 'ticketanalytics' } }
    }.to_json
  end

  def d_query_hash(params)
    @action_hash = []
    TicketConstants::LIST_FILTER_MAPPING.each do |key, val| # constructs hash for custom_filters
      @action_hash.push('condition' => val, 'operator' => 'is_in', 'value' => params[key].to_s) if params[key].present?
    end
    predefined_filters_hash(params) # constructs hash for predefined_filters
    @action_hash
  end

  def predefined_filters_hash(params)
    if sanitize_filter_params(params) # sanitize filter name
      assign_filter_params(params) # assign filter_name param
      custom_tkt_filter = Helpdesk::Filters::CustomTicketFilter.new
      @action_hash.push(custom_tkt_filter.default_filter(params[:filter_name])).flatten!
    end
  end

  def sanitize_filter_params(params)
    if TicketFilterConstants::RENAME_FILTER_NAMES.keys.include?(params[:filter])
      params[:filter] = TicketFilterConstants::RENAME_FILTER_NAMES[params[:filter]]
    elsif @action_hash.empty?
      params[:filter] ||= DEFAULT_TICKET_FILTER
    end
    params[:filter]
  end

  def assign_filter_params(params)
    params_hash = { filter_name: params[:filter] }
    params.merge!(params_hash)
  end

  def filter_factory_es_cluster_response_stub(query_hash, wf_order = 'created_at', wf_order_type = 'desc')
    query_hash_params = {}
    query_hash_params[:query_hash] = query_hash
    query_hash_params[:wf_model] = 'Helpdesk::Ticket'
    query_hash_params[:wf_order] = wf_order
    query_hash_params[:wf_order_type] = wf_order_type
    query_hash_params[:data_hash] = QueryHash.new(query_hash_params[:query_hash].values).to_system_format
    param_object = OpenStruct.new(stats: true)

    ticket_ids = private_api_ticket_index_first_page_objects(query_hash_params).map(&:id)
    {
      total: 31,
      results: ticket_ids.map { |id| { id: id, document: 'ticketanalytics' } }
    }.to_json
  end

  def public_api_filter_factory_es_cluster_response_stub(query_hash, wf_order = 'created_at', wf_order_type = 'desc')
    query_hash_params = {}
    query_hash_params[:wf_model] = 'Helpdesk::Ticket'
    query_hash_params[:wf_order] = wf_order
    query_hash_params[:wf_order_type] = wf_order_type
    query_hash_params[:data_hash] = d_query_hash(query_hash)
    query_hash_params[:per_page] = query_hash[:per_page] if query_hash[:per_page]
    stats = query_hash[:include] == 'stats'
    requester = query_hash[:include] == 'requester'
    description = query_hash[:include] == 'description'
    param_object = OpenStruct.new(stats: stats, requester: requester, description: description)

    ticket_ids = private_api_ticket_index_first_page_objects(query_hash_params).map(&:id)
    {
      total: 31,
      results: ticket_ids.map { |id| { id: id, document: 'ticketanalytics' } }
    }.to_json
  end

  def filter_factory_es_cluster_response_with_raw_query_stub(sql_query, wf_order = 'created_at')
    per_page = ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]
    ticket_ids = Account.current.tickets.where(sql_query).order('created_at desc').first(per_page).map(&:id)
    {
      total: 31,
      results: ticket_ids.map { |id| { id: id, document: 'ticketanalytics' } }
    }.to_json
  end

  def filter_factory_filter_es_response_stub(filter_data)
    ticket_ids = private_api_ticket_index_first_page_objects(filter_data).map(&:id)
    {
      total: 31,
      results: ticket_ids.map { |id| { id: id, document: 'ticketanalytics' } }
    }.to_json
  end

  def private_api_ticket_index_filter_pattern(filter_data)
    param_object = OpenStruct.new(stats: true)
    pattern_array = private_api_ticket_index_first_page_objects(filter_data).map do |ticket|
      index_ticket_pattern_with_associations(ticket, param_object, [:tags])
    end
  end

  def filter_factory_default_filter_es_response_stub(filter_name, order_by = 'created_at', order_type = 'desc')
    query_hash_params = {}
    query_hash_params[:wf_model] = 'Helpdesk::Ticket'
    filter = Helpdesk::Filters::CustomTicketFilter.new.default_filter(filter_name)
    query_hash_params[:data_hash] = filter
    query_hash_params[:wf_order] = order_by
    query_hash_params[:wf_order_type] = order_type
    param_object = OpenStruct.new(stats: true)

    ticket_ids = private_api_ticket_index_first_page_objects(query_hash_params).map(&:id)
    {
      total: 31,
      results: ticket_ids.map { |id| { id: id, document: 'ticketanalytics' } }
    }.to_json
  end

  def private_api_ticket_index_default_filter_pattern(filter_name, order_by = 'created_at', order_type = 'desc')
    query_hash_params = {}
    query_hash_params[:wf_model] = 'Helpdesk::Ticket'
    filter = Helpdesk::Filters::CustomTicketFilter.new.default_filter(filter_name)
    query_hash_params[:data_hash] = filter
    query_hash_params[:wf_order] = order_by
    query_hash_params[:wf_order_type] = order_type
    param_object = OpenStruct.new(stats: true)
    pattern_array = private_api_ticket_index_first_page_objects(query_hash_params).map do |ticket|
      index_ticket_pattern_with_associations(ticket, param_object, [:tags])
    end
  end

  def ticket_show_pattern(ticket, survey_result = nil, requester = false)
    param_object = OpenStruct.new(stats: true)
    pattern = ticket_pattern_with_association(ticket, param_object).merge(cloud_files: Array)
    ticket_topic = ticket_topic_pattern(ticket)
    pattern[:freshcaller_call] = freshcaller_call_pattern(ticket) if freshcaller_call_pattern(ticket).present?
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
    pattern[:sender_email] = ticket.sender_email
    pattern[:channel_info] = channel_info(ticket) if ticket.channel_id.present?
    pattern
  end

  def channel_info(ticket)
    {
      id: ticket.channel_id,
      profile_unique_id: ticket.channel_profile_unique_id,
      message_id: ticket.channel_message_id
    }
  end

  def ticket_requester_pattern(requester)
    req_hash = {
      name: requester.name,
      job_title: requester.job_title,
      email: requester.email,
      phone: requester.phone,
      mobile: requester.mobile,
      twitter_id: requester.twitter_id,
      id: requester.id,
      has_email: requester.email.present?,
      active: requester.active,
      avatar: requester.avatar,
      language: requester.language,
      address: requester.address
    }
    req_hash[:facebook_id] = requester.fb_profile_id if requester.fb_profile_id
    req_hash[:external_id] = requester.external_id if requester.external_id
    default_company = get_default_company(requester)
    req_hash[:company] = company_hash(default_company) if default_company.present? && default_company.company.present?
    req_hash[:other_companies] = other_companies_hash(true, requester) if Account.current.multiple_user_companies_enabled? && requester.company_id.present?
    req_hash[:unique_external_id] = requester.unique_external_id if Account.current.unique_contact_identifier_enabled? && requester.unique_external_id
    req_hash
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
        permission: User.current.has_read_ticket_permission?(item),
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

  def freshcaller_call_pattern(ticket)
    call = ticket.freshcaller_call
    return unless call.present?
    {
      id: call.id,
      fc_call_id: call.fc_call_id,
      recording_status: call.recording_status
    }
  end

  def ticket_meta_pattern(ticket)
    meta_info = ticket.notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token['meta']).body
    meta_info = YAML.load(meta_info)
    handle_secret_id(meta_info, ticket) if Account.current.agent_collision_revamp_enabled?
    handle_timestamps(meta_info)
  rescue
    {}
  end

  def handle_secret_id(meta_info, ticket)
    meta_info[:secret_id] = mask_id(ticket.display_id)
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
      meta_info['time'] = Time.parse(meta_info['time'].to_s).utc.iso8601
    end
    meta_info
  end

  def new_freshcaller_call
    create_test_freshcaller_account if @account.freshcaller_account.blank?
    @call = create_freshcaller_call
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

  def new_ticket_from_freshcaller_call(ticket = nil)
    new_freshcaller_call
    @ticket = ticket || create_ticket
    associate_call_to_item(@ticket)

    new_freshcaller_call
    note = create_normal_reply_for(@ticket)
    associate_call_to_item(note)
    @ticket
  end

  def new_ticket_from_forum_topic(params = {})
    topic = create_test_topic(Forum.first || create_test_forum(create_test_category))
    ticket = create_ticket(params)
    create_ticket_topic_mapping(topic, ticket)
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

  def conversations_pattern_freshcaller(ticket, requester = false, limit = false)
    notes_pattern = ticket.notes.visible.exclude_source('meta').order(:created_at).map do |n|
      note_pattern = note_pattern_index_freshcaller(n)
      note_pattern[:requester] = Hash.new if requester
      note_pattern
    end
    limit ? notes_pattern.take(limit) : notes_pattern
  end

  def conversations_pattern_facebook_parent(ticket, order_by = 'created_at', order_type = '', limit = false)
    order = "#{order_by} #{order_type}"
    ancestry = fetch_fb_post_ancestry(ticket)
    notes = ticket.notes.parent_facebook_comments(ancestry, nil, order)
    child_conversations_count = child_conversations_count(fetch_fb_post_ancestry_ids(ticket, notes))
    notes_pattern = notes.map do |n|
      note_pattern = note_pattern_index_freshcaller(n)
      if n.fb_note? && n.fb_post.present?
        note_pattern.merge!(child_count: child_conversations_count.fetch(n.id, 0))
        note_pattern.merge!(fb_post: FacebookPostDecorator.new(n.fb_post).to_hash)
      end
      note_pattern
    end
    limit ? notes_pattern.take(limit) : notes_pattern
  end

  def child_conversations_count(note_ancestry_mapping)
    count_ancestry_mapping = Account.current.facebook_posts.total_child_posts(note_ancestry_mapping.keys)

    count_ancestry_mapping.each_with_object({}) do |fb_post, h|
      h[note_ancestry_mapping[fb_post.ancestry]] = fb_post.child_posts_count
    end
  end

  def conversations_pattern_facebook_child(ticket, parent_id, order_by = 'created_at', order_type = 'desc', limit = false)
    order = "#{order_by} #{order_type}"
    ancestry = fetch_fb_post_ancestry(ticket, parent_id)
    notes_pattern = ticket.notes.child_facebook_comments(ancestry, nil, order).map do |n|
      note_pattern = note_pattern_index_freshcaller(n)
      note_pattern.delete(:ticket_id)
      note_pattern.merge!(parent_id: parent_id.to_i)
      note_pattern
    end
    limit ? notes_pattern.take(limit) : notes_pattern
  end

  def fetch_fb_post_ancestry(ticket, note_id = nil)
    if note_id.blank?
      ticket.fb_post.id.to_s
    else
      note_fb_post = Account.current.facebook_posts.where(postable_type: 'Helpdesk::Note', postable_id: note_id).last
      format(NOTE_ANCESTRY, ticket_fb_post_id: ticket.fb_post.id, note_fb_post_id: note_fb_post.id)
    end
  end

  def fetch_fb_post_ancestry_ids(ticket, notes)
    notes.each_with_object({}) do |note, h|
      h[format(NOTE_ANCESTRY, ticket_fb_post_id: ticket.fb_post.id, note_fb_post_id: note.fb_post.id)] = note.id if note.fb_post.present?
    end
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
    single_note
  end

  def note_pattern_index_freshcaller(note)
    index_note = {
      from_email: note.from_email,
      cc_emails:  note.cc_emails,
      bcc_emails: note.bcc_emails,
      source: note.source
    }
    single_note = private_note_pattern({}, note)
    single_note.merge!(index_note)
    single_note[:freshcaller_call] = freshcaller_call_pattern(note) if freshcaller_call_pattern(note)
    single_note
  end

  def create_parent_child_tickets
    @parent_ticket = create_parent_ticket
    @child_ticket  = create_ticket(assoc_parent_id: @parent_ticket.display_id)
  end

  def create_advanced_tickets(count = {fsm: 1})
    child_tickets = []
    @parent_ticket = create_parent_ticket

    (count[:fsm] || 0).times { child_tickets << create_ticket(assoc_parent_id: @parent_ticket.display_id, type: "Service Task") }
    (count[:pc] || 0).times { child_tickets << create_ticket(assoc_parent_id: @parent_ticket.display_id) }

    child_tickets.map(&:display_id)
  end

  def create_ticket_with_attachments(min = 0, max = 1)
    ticket = create_ticket
    rand(min..max).times do
      ticket.attachments << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id)
    end
    ticket.save
    ticket
  end

  def create_ticket_with_inline_attachments(min = 0, max = 1)
    ticket = create_ticket
    rand(min..max).times do
      ticket.inline_attachments << create_attachment(attachable_type: 'Ticket::Inline', attachable_id: ticket.id)
    end
    ticket.save
    ticket
  end

  def create_parent_ticket
    create_ticket
    parent_ticket = Helpdesk::Ticket.last
    parent_ticket.update_attributes(association_type: 1, subsidiary_tkts_count: 1)
    parent_ticket
  end

  def create_tracker_ticket(params = {})
    create_ticket(params)
    tracker_ticket = Helpdesk::Ticket.last
    tracker_ticket.update_attributes(association_type: 3, subsidiary_tkts_count: 1)
    tracker_ticket
  end

  def create_related_tickets(related_count = 1)
    related_count.times.collect do |i|
      related_ticket = create_ticket
      related_ticket.update_attributes(association_type: 4)
      related_ticket
    end
  end

  def create_article_feedback_ticket(article_id)
    ticket = create_ticket
    ticket.create_article_ticket(article_id: article_id)
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
    ticket = create_ticket
    tracker_ticket = create_tracker_ticket
    @ticket_id = ticket.display_id
    @tracker_id = tracker_ticket.display_id
    link_to_tracker(ticket, tracker_ticket)
  end

  def create_linked_tickets_with_group(ticket_group_id, tracker_group_id = nil)
    ticket = create_ticket
    ticket.group_id = ticket_group_id
    tracker_ticket = create_tracker_ticket
    if tracker_group_id
      tracker_ticket.group_id = tracker_group_id
      tracker_ticket.save!
    end
    @ticket_id = ticket.display_id
    @tracker_id = tracker_ticket.display_id
    link_to_tracker(ticket, tracker_ticket)
  end

  def link_to_tracker(ticket, tracker_ticket)
    ticket.association_type = 4
    ticket.tracker_ticket_id = tracker_ticket.display_id
    ticket.save!
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

  def create_skill
    @group_with_sbrr_enabled = []
    @skills = []
    2.times do
      @group_with_sbrr_enabled << create_group(@account, ticket_assign_type: 2, toggle_availability: 1, capping_limit: 5)
      @skills << @account.skills.create(
        name: Faker::Lorem.words(3).join(' '),
        match_type: 'all'
      )
    end
  end

  def create_skill_tickets
    create_skill if @account.skills.empty?
    group_with_sbrr_enabled = Account.current.groups.where(ticket_assign_type: 2)
    skills = Account.current.skills
    3.times do
      create_ticket(group: group_with_sbrr_enabled[0], skill_id: skills[0].id)
      create_ticket(group: group_with_sbrr_enabled[1], skill_id: skills[1].id)
    end
  end

  def sbrr_create_skill_tickets(requester_id)
    create_skill
    group_with_sbrr_enabled = Account.current.groups.where(ticket_assign_type: 2)
    ticket = create_ticket({ skip_sbrr_assigner: false, skill: @skills[0], skill_id: @skills[0].id, requester_id: requester_id }, group_with_sbrr_enabled[0])
    [@skills[0].id, group_with_sbrr_enabled[0].id, ticket]
  end

  def sbrr_setup
    if @account.agents.first
      agent = @account.agents.first
    else
      agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com"})
    end
    agent.available = true
    agent.save!
    user_id = agent.user_id
    skill_id, group_id, ticket = sbrr_create_skill_tickets user_id
    agent_group = @account.agent_groups.build(user_id: user_id, group_id: group_id)
    agent_group.save!
    user_skill = UserSkill.new(user_id: user_id, skill_id: ticket.sl_skill_id)
    user_skill.save!
    [user_id, ticket]
  end

  def create_archive_and_child(ticket)
    Account.current.features.archive_tickets.create
    archive_ticket = Helpdesk::ArchiveTicket.new
    archive_ticket.subject = 'Test archive ticket'
    archive_ticket.save
    archive_child = Helpdesk::ArchiveChild.new
    archive_child.ticket_id = ticket.id
    archive_child.archive_ticket_id = archive_ticket.id
    archive_child.save
    archive_ticket
  end

  # export methods
  def ticket_data_export(source)
    @account.data_exports.order(:id).where(user_id: User.current.id, source: source)
  end

  def export_ticket_fields
    Hash[*Helpdesk::TicketModelExtension.allowed_ticket_export_fields.map { |i| [i, i] }.flatten].symbolize_keys
  end

  def ticket_export_param
    {
      ticket_fields: export_ticket_fields,
      contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
      company_fields: { 'name' => 'Company Name' },
      format: 'csv', date_filter: '4',
      ticket_state_filter: 'created_at', start_date: 1.day.ago.iso8601, end_date: Time.zone.now.iso8601,
      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w(2 5) }]
    }
  end

  def stub_requirements_for_stats
    CustomRequestStore.store[:channel_api_request] = true
    @channel_v2_api = true
    TicketDecorator.any_instance.stubs(:private_api?).returns(true)
    Account.any_instance.stubs(:count_es_enabled?).returns(true)
    Account.any_instance.stubs(:api_es_enabled?).returns(true)
  end

  def unstub_requirements_for_stats
    TicketDecorator.any_instance.unstub(:private_api?)
    Account.any_instance.unstub(:count_es_enabled?)
    Account.any_instance.unstub(:api_es_enabled?)
    @channel_v2_api = false
    CustomRequestStore.store[:channel_api_request] = false
  end

  def source_additional_info(ticket)
    return nil unless ticket.twitter? || ticket.facebook?

    info = {}
    info[:twitter] = tweet_hash(ticket) if ticket.twitter?
    info[:facebook] = facebook_hash(ticket) if ticket.facebook?
    info
  end

  def tweet_hash(ticket)
    handle = ticket.tweet.twitter_handle
    twitter_requester = ticket.requester
    tweet_hash = {
      id: ticket.tweet.tweet_id.to_s,
      type: ticket.tweet.tweet_type,
      support_handle_id: handle.twitter_user_id.to_s,
      support_screen_name: handle.screen_name,
      requester_screen_name: Account.current.twitter_api_compliance_enabled? && public_v2_api? ? twitter_requester.twitter_requester_handle_id : twitter_requester.twitter_id
    }
    if @channel_v2_api
      tweet_hash.merge!(stream_id: ticket.tweet.stream_id)
    end
    tweet_hash
  end

  def facebook_hash(ticket)
    ticket.fb_post.post? ? fb_public_post_pattern({}, ticket.fb_post) : fb_public_dm_pattern({}, ticket.fb_post)
  end

  def validation_error_pattern(value)
    {
      description: 'Validation failed',
      errors: [value]
    }
  end

  # Save dummy fb page
  def fetch_or_create_fb_page
    id = @account.facebook_pages.last.page_id if @account.facebook_pages.last.present?
    return id if id.present?
    Social::FacebookPage.any_instance.stubs(:check_subscription).returns(true)
    Social::FacebookPage.any_instance.stubs(:subscribe_realtime).returns(true)
    fb_page = @account.facebook_pages.new(fb_page_params_hash)
    fb_page.save
    @account.facebook_pages.last.page_id
  end

  def create_ebay_ticket
    ebay_account = @account.ebay_accounts.new(name: Faker::Lorem.characters(10), configs: {}, status: 2, reauth_required: false)
    ebay_account.external_account_id = Faker::Number.number(10)
    ebay_account.save
    ecommerce_ticket = create_ticket(source: Helpdesk::Source::ECOMMERCE)
    ecommerce_ticket.requester.external_id = 'bssmb_us_03'
    ecommerce_ticket.requester.save
    ecommerce_ticket.build_ebay_question(user_id: ecommerce_ticket.requester.id, item_id: Faker::Number.number(10).to_s, ebay_account_id: ebay_account.id, account_id: @account.id, message_id: Faker::Number.number(10).to_s)
    ecommerce_ticket.ebay_question.save
    ecommerce_ticket.reload
    ecommerce_ticket
  end

  def tickets_sync_pattern(job_id)
    { 'job_id' => job_id }
  end
end
