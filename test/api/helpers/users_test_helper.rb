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
    custom_field = contact.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v] }.to_h
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
      avatar: expected_output[:avatar] || get_contact_avatar(contact)
    }

    result.merge!(
      other_emails: expected_output[:other_emails] ||
      contact.user_emails.where(primary_role: false).map(&:email)
    )
    result.merge!(
      other_companies: expected_output[:other_companies] ||
      get_other_companies(contact)
    )
    result.merge!(deleted: true) if contact.deleted
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
      contact_avatar.merge!({
        # changing from direct url to string because of changing X-Amz-Signature in the URL
        attachment_url: String,
        thumb_url: String
      })
    else
      contact_avatar[:avatar_url] = String
    end
    contact_avatar
  end

  def deleted_contact_pattern(expected_output = {}, contact)
    contact_pattern(expected_output, contact).merge(deleted: (expected_output[:deleted] || contact.deleted).to_s.to_bool)
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

  def index_contact_pattern(contact)
    keys = [
      :avatar, :tags, :other_emails, :deleted,
      :other_companies, :view_all_tickets
    ]
    keys -= [:deleted] if contact.deleted
    contact_pattern(contact).except(*keys)
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
    comp  = Company.first || create_company
    {
      name: Faker::Lorem.characters(10), address: Faker::Lorem.characters(10), phone: '1234567890',
      mobile: '1234567891', description: Faker::Lorem.characters(20), email: Faker::Internet.email,  job_title: Faker::Lorem.characters(10),
      language: 'en', time_zone: 'Chennai', company_id: comp.id
    }
  end

  def v2_contact_params
    comp  = create_company
    {
      name: Faker::Lorem.characters(10), address: Faker::Lorem.characters(10),  phone: '1234567892',
      mobile: '1234567893', description: Faker::Lorem.characters(20), email: Faker::Internet.email,  job_title: Faker::Lorem.characters(10),
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
    new_user.save
    new_user
  end

  def confirm_user_whitelisting(ids = [])
    return if ids.blank?
    @account.users.where(id: ids).each do |user|
      refute user.blocked
      refute user.deleted
      assert user.blocked_at == nil
      assert user.whitelisted
    end
  end

  def random_password
    Faker::Lorem.words(5).join[0..10]
  end

  def create_tweet_user
    user = Account.current.users.build(
      name:       Faker::Name.name,
      twitter_id: Faker::Lorem.word
    )
    user.save
    user
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
    contact.save
  end

  def private_api_index_contact_pattern
    users = @account.all_contacts.order('users.name').select { |x| x.deleted == false && x.blocked == false }
    users.first(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]).map do |contact|
      contact_pattern(contact)
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
    unless @account.features.archive_tickets?
      @account.features.archive_tickets.create
      @account.reload
    end
    count.times do
      @account.make_current
      temp_ticket = create_ticket(requester_id: contact.id)
      Sidekiq::Testing.inline! do
        Archive::BuildCreateTicket.perform_async({ account_id: @account.id, ticket_id: temp_ticket.id })
      end
    end
    @account.archive_tickets.permissible(@agent).requester_active(contact).newest(10)
  end

  def user_combined_activities(contact)
    sample_user_topics(contact, 5)
    tickets = sample_user_tickets(contact, 5)
    tickets + contact.recent_posts
  end

  def user_activity_response(objects, meta = false)
    response_pattern = objects.map do |item|
      {
        type: item.class.name.gsub('Helpdesk::', ''),
        created_at: item.created_at
      }.merge(object_activity_pattern(item))
    end
    response_pattern
  end

  def object_activity_pattern(obj)
    obj.class.name == 'Post' ? forum_activity_pattern(obj) : ticket_activity_pattern(obj)
  end

  def ticket_activity_pattern(obj)
    {
      id: obj.display_id,
      subject: obj.subject,
      status: obj.status,
      agent_id: obj.responder.try(:id)
    }
  end

  def forum_activity_pattern(obj)
    {
      id: obj.id,
      topic_id: obj.topic.id,
      topic_title: obj.topic.title,
      replied: obj.original_post? ? false : true 
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
end
