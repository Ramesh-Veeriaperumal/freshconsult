['company_helper.rb', 'contact_fields_helper.rb', 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module UsersTestHelper
  include CompanyHelper
  include GroupHelper
  include ContactFieldsHelper
  # Patterns
  def contact_pattern(expected_output = {}, ignore_extra_keys = true, contact)
    expected_custom_field = (expected_output[:custom_fields] && ignore_extra_keys) ? expected_output[:custom_fields].ignore_extra_keys! : expected_output[:custom_fields]
    custom_field = contact.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v] }.to_h
    contact_custom_field = (custom_field && ignore_extra_keys) ? custom_field.ignore_extra_keys! : custom_field

    if contact.avatar
      contact_avatar = {

        content_type: contact.avatar.content_content_type,
        size: contact.avatar.content_file_size,
        name: contact.avatar.content_file_name,
        avatar_url: String,
        created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        id: contact.avatar.id
      }
    end

    result = {
      active: expected_output[:active] || contact.active,
      address: expected_output[:address] || contact.address,
      company_id: expected_output[:company_id] || contact.company_id,
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
      avatar: expected_output[:avatar] || contact_avatar

    }

    result.merge!(other_emails: expected_output[:other_emails] || contact.user_emails.where(primary_role: false).map(&:email))
    result.merge!(deleted: true) if contact.deleted
    result
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
    keys = [:avatar, :tags, :other_emails, :deleted]
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
end
