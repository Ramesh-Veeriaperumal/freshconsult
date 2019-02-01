['company_helper.rb', 'contact_fields_helper.rb', 'group_helper.rb', 'agent_helper.rb', 'forum_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module UsersTestHelper
  include CompanyHelper
  include GroupHelper
  include ContactFieldsHelper
  include AgentHelper
  include ForumHelper

  # Patterns
  def contact_pattern(expected_output = {}, ignore_extra_keys = true, contact)
    expected_custom_field = (expected_output[:custom_fields] && ignore_extra_keys) ? expected_output[:custom_fields].ignore_extra_keys! : expected_output[:custom_fields]
    custom_field = contact.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v.respond_to?(:utc) ? v.strftime('%F') : v] }.to_h
    contact_custom_field = (custom_field && ignore_extra_keys) ? custom_field.ignore_extra_keys! : custom_field

    result = {
      active: expected_output[:active] || contact.active,
      address: expected_output[:address] || contact.address,
      company_id: expected_output[:company_id] || get_company_id(contact),
      view_all_tickets: expected_output[:view_all_tickets] || get_client_manager(contact),
      description: expected_output[:description] || contact.description,
      email: expected_output[:email] || contact.email,
      id: Fixnum,
      job_title: expected_output[:job_title] || contact.job_title,
      language: expected_output[:language] || contact.language,
      mobile: expected_output[:mobile] || contact.mobile,
      name: expected_output[:name] || contact.name,
      phone: expected_output[:phone] || contact.phone,
      tags: expected_output[:tags] || contact.tags.map(&:name),
      time_zone: expected_output[:time_zone] || contact.time_zone,
      twitter_id: expected_output[:twitter_id] || contact.twitter_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      custom_fields:  expected_custom_field || contact_custom_field,
      avatar: expected_output[:avatar] || get_contact_avatar(contact),
      facebook_id: expected_output[:facebook_id] || contact.fb_profile_id,
      was_agent: expected_output[:was_agent] || contact.was_agent?,
      agent_deleted_forever: expected_output[:agent_deleted_forever] || contact.agent_deleted_forever?,
      marked_for_hard_delete: expected_output[:marked_for_hard_delete] || contact.marked_for_hard_delete?
    }
    result[:other_emails] = expected_output[:other_emails] ||
                            contact.user_emails.where(primary_role: false).map(&:email)
    result[:other_companies] = expected_output[:other_companies] ||
                               get_other_companies(contact) if Account.current.multiple_user_companies_enabled?

    result[:unique_external_id] = expected_output[:unique_external_id] || contact.unique_external_id if Account.current.unique_contact_identifier_enabled?
    result[:deleted] = true if contact.deleted
    result
  end

  def private_api_contact_pattern(expected_output = {}, ignore_extra_keys = true, exclude_custom_fields = false, contact)
    result = contact_pattern(expected_output, ignore_extra_keys, contact)
    result.except!(:other_companies)
    result.except!(:custom_fields) if result[:custom_fields].empty? || exclude_custom_fields
    result.merge!(whitelisted: contact.whitelisted,
                  facebook_id: (expected_output[:facebook_id] || contact.fb_profile_id),
                  external_id: (expected_output[:external_id] || contact.external_id),
                  unique_external_id: (expected_output[:unique_external_id] || contact.unique_external_id),
                  blocked: contact.blocked?,
                  spam: contact.spam?,
                  deleted: contact.deleted,
                  parent_id: contact.parent_id)
    result[:company] = company_hash(contact.default_user_company) if expected_output[:include].eql?('company') && contact.default_user_company.present?
    result[:other_companies] = other_companies_hash(expected_output[:include].eql?('company'), contact) if Account.current.multiple_user_companies_enabled? && contact.default_user_company.present?
    result
  end

  def get_contact_avatar(contact)
    return nil unless contact.avatar
    contact_avatar = {
      content_type: contact.avatar.content_content_type,
      size: contact.avatar.content_file_size,
      name: contact.avatar.content_file_name,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      id: contact.avatar.id
    }

    if @private_api
      contact_avatar[:attachment_url] = String
      contact_avatar[:thumb_url] = String
    else
      contact_avatar[:avatar_url] = String
    end
    contact_avatar
  end

  def deleted_contact_pattern(expected_output = {}, contact)
    ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
    contact_pattern(expected_output, contact).merge(deleted: (expected_output[:deleted] || contact.deleted).to_s.to_bool).except(*ignore_keys)
  end

  def unique_external_id_contact_pattern(expected_output = {}, contact)
    ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
    contact_pattern(expected_output, contact).merge!(unique_external_id: expected_output[:unique_external_id] || contact.unique_external_id).except(*ignore_keys)
  end

  def deleted_unique_external_id_contact_pattern(expected_output = {}, contact)
    deleted_contact_pattern(expected_output, contact).merge!(unique_external_id: expected_output[:unique_external_id] || contact.unique_external_id)
  end

  def make_agent_pattern(expected_output = {}, agent_user)
    agent = agent_user.agent
    agent_pattern = {
      available_since: agent.active_since,
      available: agent.available,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      id: Fixnum,
      occasional: expected_output[:occasional] || agent.occasional,
      signature: expected_output[:signature] || agent.signature_html,
      ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      role_ids: expected_output[:role_ids] || agent_user.role_ids,
      group_ids: expected_output[:group_ids] || agent.group_ids
    }
    {
      active: agent_user.active,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      email: agent_user.email,
      job_title: agent_user.job_title,
      language: agent_user.language,
      last_login_at: agent_user.last_login_at,
      mobile: agent_user.mobile,
      name: agent_user.name,
      phone: agent_user.phone,
      time_zone: agent_user.time_zone,
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      agent: agent_pattern
    }
  end

  def deleted_agent_pattern(expected_output = {}, agent_user)
    {
      active: expected_output[:active] || agent_user.active,
      email: expected_output[:email] || agent_user.email,
      job_title: expected_output[:job_title] || agent_user.job_title,
      language: expected_output[:language] || agent_user.language,
      mobile: expected_output[:mobile] || agent_user.mobile,
      name: expected_output[:name] || agent_user.name,
      phone: expected_output[:phone] || agent_user.phone,
      time_zone: expected_output[:time_zone] || agent_user.time_zone,
      avatar: expected_output[:avatar] || agent_user.avatar,
      id: expected_output[:id] || agent_user.id,
      deleted: expected_output[:deleted] || agent_user.deleted,
      deleted_agent: true
    }
  end

  def index_contact_pattern(contact)
    keys = [
      :avatar, :tags, :other_emails, :deleted,
      :other_companies, :view_all_tickets, :was_agent, :agent_deleted_forever, :marked_for_hard_delete
    ]
    keys -= [:deleted] if contact.deleted
    contact_pattern(contact).except(*keys)
  end

  def public_search_contact_pattern(contact)
    keys = [
      :avatar, :tags, :other_emails, :deleted,
      :other_companies, :view_all_tickets, :was_agent, :agent_deleted_forever, :marked_for_hard_delete, :facebook_id, :unique_external_id
    ]
    keys -= [:deleted] if contact.deleted
    contact_pattern(contact).except(*keys)
  end

  def index_contact_pattern_with_unique_external_id(contact)
    keys = [:avatar, :tags, :other_emails, :deleted, :view_all_tickets, :other_companies]
    keys -= [:deleted] if contact.deleted
    unique_external_id_contact_pattern(contact).except(*keys)
  end

  def v1_contact_payload
    { user: v1_contact_params }.to_json
  end

  def v2_contact_payload
    v2_contact_params.to_json
  end

  def v2_multipart_payload
    {
      name: Faker::Name.name,
      email: Faker::Internet.email,
      avatar: Rack::Test::UploadedFile.new(Rails.root.join('test/api/fixtures/files/image33kb.jpg'), 'image/jpg')
    }
  end

  def v1_contact_update_payload
    { user: v1_contact_params.except(:name, :email) }.to_json
  end

  def v2_contact_update_payload
    v2_contact_params.except(:name, :email).to_json
  end

  # private
  def v1_contact_params
    comp = Company.first || create_company
    {
      name: Faker::Lorem.characters(10), address: Faker::Lorem.characters(10), phone: '1234567890',
      mobile: '1234567891', description: Faker::Lorem.characters(20), email: Faker::Internet.email, job_title: Faker::Lorem.characters(10),
      language: 'en', time_zone: 'Chennai', company_id: comp.id
    }
  end

  def v2_contact_params
    comp = create_company
    {
      name: Faker::Lorem.characters(10), address: Faker::Lorem.characters(10), phone: '1234567892',
      mobile: '1234567893', description: Faker::Lorem.characters(20), email: Faker::Internet.email, job_title: Faker::Lorem.characters(10),
      language: 'en', time_zone: 'Chennai', company_id: comp.id
    }
  end

  def other_emails_for_test(contact)
    contact.user_emails.reject(&:primary_role).map(&:email)
  end

  def add_user_email(contact, email, options = {})
    params = { email: email, user_id: contact.id }
    params.merge!(options) if options.any?
    u = UserEmail.new(params)
    u.save
  end

  def create_blocked_contact(account)
    new_user = add_new_user(account)
    new_user.blocked = true
    new_user.blocked_at = Time.now
    new_user.save_without_session_maintenance
    new_user
  end

  def create_contact_with_other_companies(account, company_ids = nil)
    company_ids ||= Company.first(2).map(&:id)
    new_user = add_new_user(account)
    company_attributes = []
    company_ids.each do |c|
      h = { company_id: c, client_manager: true }
      h[:default] = true if c == company_ids.first
      company_attributes << h
    end
    new_user.user_companies_attributes = Hash[(0...company_attributes.size).zip company_attributes]
    new_user.save_without_session_maintenance
    new_user
  end

  def confirm_user_whitelisting(ids = [])
    return if ids.blank?
    @account.users.where(id: ids).each do |user|
      refute user.blocked
      refute user.deleted
      assert user.blocked_at.nil?
      assert user.whitelisted
    end
  end

  def random_password
    Faker::Lorem.words(5).join[0..10]
  end

  def create_tweet_user(details = {})
    user = Account.current.users.build(
      name:      details[:name] ||  Faker::Name.name,
      twitter_id: details[:screen_name] || Faker::Lorem.word
    )
    user.save_without_session_maintenance
    user
  end

  def assume_identity_error_pattern
    {
      description: 'Validation failed',
      errors: [
        {
          field: 'assume_identity',
          message: 'You are not allowed to assume this user.',
          code: 'invalid_value'
        }
      ]
    }
  end

  def password_change_error_pattern(error_type)
    {
      description: 'Validation failed',
      errors: [
        send("password_#{error_type}_error")
      ]
    }
  end

  def password_not_allowed_error
    {
      field: 'password',
      message: 'Not allowed to change.',
      code: 'invalid_value'
    }
  end

  def password_missing_field_error
    {
      field: 'password',
      message: 'It should be a/an String',
      code: 'missing_field'
    }
  end

  def password_datatype_mismatch_error
    {
      field: 'password',
      message: 'Value set is of type Null.It should be a/an String',
      code: 'datatype_mismatch'
    }
  end

  def add_avatar_to_user(contact)
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
    contact.build_avatar(
      content: file,
      description: Faker::Lorem.characters(10),
      account_id: @account.id
    )
    contact.save_without_session_maintenance
  end

  def private_api_index_contact_pattern
    users = @account.all_contacts.order('users.name').select { |x| x.deleted == false && x.blocked == false }
    users.first(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]).map do |contact|
      private_api_contact_pattern(contact)
    end
  end

  def sample_user_topics(contact, count = 2)
    forum = create_test_forum(create_test_category)
    count.times do
      create_test_topic(forum, contact)
    end
  end

  def sample_user_tickets(contact, count = 2)
    @account.make_current
    count.times do
      create_ticket(requester_id: contact.id)
    end
    @user_tickets = @account.tickets.permissible(@agent).requester_active(contact).visible.newest(11)
    @user_tickets.take(10)
  end

  def sample_user_archived_tickets(contact, count = 1)
    count.times do
      @account.make_current
      temp_ticket = create_ticket(requester_id: contact.id, status: 5)
      Sidekiq::Testing.inline! do
        Archive::BuildCreateTicket.perform_async(account_id: @account.id, ticket_id: temp_ticket.id)
      end
    end
    @account.archive_tickets.permissible(@agent).requester_active(contact).newest(10)
  end

  def user_combined_activities(contact)
    sample_user_topics(contact, 5)
    tickets = sample_user_tickets(contact, 5)
    act = tickets + contact.recent_posts
    act.sort_by { |item| - item.created_at.to_i }
  end

  def user_activity_response(objects, _meta = false)
    response_pattern = {}
    objects.map do |item|
      archived?(item) ? type = "ticket" : type = item.class.name.gsub('Helpdesk::', '').downcase
      to_ret = object_activity_pattern(item)
      (response_pattern[type.to_sym] ||= []).push to_ret
    end
    response_pattern
  end

  def object_activity_pattern(obj)
    obj.class.name == 'Post' ? forum_activity_pattern(obj) : ticket_activity_pattern(obj)
  end

  def ticket_activity_pattern(obj)
    ret_hash = {
      id: obj.display_id,
      responder_id: obj.responder_id,
      subject: obj.subject,
      requester_id: obj.requester_id,
      group_id: obj.group_id,
      source: obj.source,
      created_at: obj.created_at.try(:utc).try(:iso8601)
    }
    ret_hash.merge!(whitelisted_properties_for_activities(obj))
    ret_hash
  end
  
  def whitelisted_properties_for_activities(obj)
    return {archived: true} if archived?(obj)
    {
      description_text: obj.description,
      due_by: obj.due_by.try(:utc).try(:iso8601),
      stats: stats(obj),
      tags: obj.tag_names,
      fr_due_by: obj.frDueBy.try(:utc).try(:iso8601),
      status: obj.status
    }
  end

  def parse_time(attribute)
    attribute ? Time.parse(attribute).utc : nil
  end

  def archived?(obj)
    @is_archived ||= obj.is_a?(Helpdesk::ArchiveTicket)
  end

  def forum_activity_pattern(obj)
    {
      id: obj.id,
      topic_id: obj.topic.id,
      title: obj.topic.title,
      comment: !obj.original_post?,
      created_at: obj.created_at.try(:utc).try(:iso8601),
      updated_at: obj.updated_at.try(:utc).try(:iso8601),
      forum: {
        id: obj.forum.id,
        name: obj.forum.name
      }
    }
  end

  def password_policy_pattern type
    policy = type=="agent" ? Account.current.agent_password_policy_from_cache : 
                             Account.current.contact_password_policy_from_cache
    return { policies: nil } unless policy.present?
    ret_hash = { 
      policies: policy.configs
    }
    policy.policies.map(&:to_s).each do |policy|
      ret_hash[:policies][policy] = true unless ret_hash[:policies].key?(policy)
    end
    ret_hash
  end

  def stats(obj)
    ticket_states = obj.ticket_states
    {
      agent_responded_at: ticket_states.agent_responded_at.try(:utc).try(:iso8601),
      requester_responded_at: ticket_states.requester_responded_at.try(:utc).try(:iso8601),
      resolved_at: ticket_states.resolved_at.try(:utc).try(:iso8601),
      first_responded_at: ticket_states.first_response_time.try(:utc).try(:iso8601),
      closed_at: ticket_states.closed_at.try(:utc).try(:iso8601),
      status_updated_at: ticket_states.status_updated_at.try(:utc).try(:iso8601),
      pending_since: ticket_states.pending_since.try(:utc).try(:iso8601),
      reopened_at: ticket_states.opened_at.try(:utc).try(:iso8601)
    }
  end

  def get_other_companies(contact)
    other_companies = []
    contact.user_companies.where(default: false).each do |company|
      other_companies << {
        company_id: company.company_id,
        view_all_tickets: company.client_manager
      }
    end
    other_companies
  end

  def other_companies_hash(include, contact)
    if include
      other_companies = []
      contact.user_companies.where(default: false).each do |uc|
        other_companies << company_hash(uc)
      end
      other_companies
    else
      contact.user_companies.reject(&:default).map(&:company_id)
    end
  end

  def company_hash(user_comp)
    {
      id: user_comp.company_id,
      name: user_comp.company.name,
      view_all_tickets: user_comp.client_manager,
      avatar: CompanyDecorator.new(user_comp.company, {}).avatar_hash
    }
  end

  def get_client_manager(contact)
    default_company = get_default_company(contact)
    default_company ? default_company.client_manager : nil
  end

  def get_company_id(contact)
    default_company = get_default_company(contact)
    default_company ? default_company.company_id : nil
  end

  def get_default_company(contact)
    contact.user_companies.find_by_default(true)
  end

  def enable_multiple_user_companies
    Account.current.add_feature(:multiple_user_companies)
    yield
  ensure
    disable_multiple_user_companies
  end

  def disable_multiple_user_companies
    Account.current.revoke_feature(:multiple_user_companies)
  end
end
