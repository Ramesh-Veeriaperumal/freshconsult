['ticket_fields_test_helper.rb', 'conversations_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['ticket_helper.rb', 'company_helper.rb', 'group_helper.rb', 'note_helper.rb', 'email_configs_helper.rb', 'products_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
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

  # Patterns
  def deleted_ticket_pattern(expected_output = {}, ticket)
    ticket_pattern(expected_output, ticket).merge(deleted: (expected_output[:deleted] || ticket.deleted).to_s.to_bool)
  end

  def index_ticket_pattern(ticket)
    ticket_pattern(ticket).except(:attachments, :conversations, :tags)
  end

  def index_ticket_pattern_with_associations(ticket, requester = true, ticket_states = true)
    ticket_pattern_with_association(ticket, false, false, requester, false, ticket_states).except(:attachments, :conversations, :tags)
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

  def ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    expected_custom_field = (expected_output[:custom_fields] && ignore_extra_keys) ? expected_output[:custom_fields].ignore_extra_keys! : expected_output[:custom_fields]
    custom_field = ticket.custom_field.map { |k, v| [TicketDecorator.display_name(k), v.respond_to?(:utc) ? v.utc.iso8601 : v] }.to_h
    ticket_custom_field = (custom_field && ignore_extra_keys) ? custom_field.as_json.ignore_extra_keys! : custom_field.as_json
    description_html = format_ticket_html(ticket, expected_output[:description]) if expected_output[:description]

    {
      cc_emails: expected_output[:cc_emails] || ticket.cc_email[:cc_emails],
      fwd_emails: expected_output[:fwd_emails] || ticket.cc_email[:fwd_emails],
      reply_cc_emails:  expected_output[:reply_cc_emails] || ticket.cc_email[:reply_cc],
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

  def update_ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    description = expected_output[:description] || ticket.description_html
    ticket_pattern(expected_output, ignore_extra_keys, ticket).merge(description: description)
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

  def latest_note_response_pattern(note)
    pattern = reply_note_pattern({}, note).merge!({ user: Hash })
    pattern.except(:user_id)
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
    match_json(ticket_pattern({}, new_ticket))
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

end
