module Helpers::UsersHelper
  # Patterns
  def contact_pattern(expected_output = {}, ignore_extra_keys = true, contact)
    expected_custom_field = (expected_output[:custom_fields] && ignore_extra_keys) ? expected_output[:custom_fields].ignore_extra_keys! : expected_output[:custom_fields]
    contact_custom_field = (contact.custom_field && ignore_extra_keys) ? contact.custom_field.ignore_extra_keys! : contact.custom_field

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

    {
      active: expected_output[:active] || contact.active,
      address: expected_output[:address] || contact.address,
      client_manager: expected_output[:client_manager] || contact.client_manager,
      company_id: expected_output[:company_id] || contact.company_id,
      description: expected_output[:description] || contact.description,
      email: expected_output[:email] || contact.email,
      id: Fixnum,
      job_title: expected_output[:job_title] || contact.job_title,
      language: expected_output[:language] || contact.language,
      mobile: expected_output[:mobile] || contact.mobile,
      name: expected_output[:name] || contact.name,
      phone: expected_output[:phone] || contact.phone,
      tags: expected_output[:tags] || contact.tags.collect(&:name),
      time_zone: expected_output[:time_zone] || contact.time_zone,
      twitter_id: expected_output[:twitter_id] || contact.twitter_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      custom_fields:  expected_custom_field || contact_custom_field,
      avatar: expected_output[:avatar] || contact_avatar

    }
  end

  def deleted_contact_pattern(expected_output = {}, contact)
    contact_pattern(expected_output, contact).merge(deleted: (expected_output[:deleted] || contact.deleted).to_s.to_bool)
  end

  def index_contact_pattern(contact)
    contact_pattern(contact).except(:avatar, :tags, :deleted)
  end

  def index_deleted_contact_pattern(contact)
    index_contact_pattern(contact).merge(deleted: contact.deleted.to_s.to_bool)
  end

  def agent_pattern(expected_output = {}, agent)
    user = {
      active: agent.user.active,
      created_at: agent.user.created_at,
      email: agent.user.email,
      job_title: agent.user.job_title,
      language: agent.user.language,
      last_login_at: agent.user.last_login_at,
      mobile: agent.user.mobile,
      name: agent.user.name,
      phone: agent.user.phone,
      time_zone: agent.user.time_zone,
      updated_at: agent.user.updated_at
    }

    {
      available_since: expected_output[:available_since] || agent.active_since,
      available: expected_output[:available] || agent.available,
      created_at: agent.created_at,
      id: Fixnum,
      occasional: expected_output[:occasional] || agent.occasional,
      signature: expected_output[:signature] || agent.signature,
      signature_html: expected_output[:signature_html] || agent.signature_html,
      ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
      updated_at: agent.updated_at,
      user: expected_output[:user] || user
    }
  end

  # Helpers
  def other_user
    u = User.find { |x| @agent.can_assume?(x) } || create_dummy_customer
    u.update_column(:email, Faker::Internet.email)
    u.reload
  end

  def deleted_user
    user = User.find { |x| x.id != @agent.id } || create_dummy_customer
    user.update_column(:deleted, true)
    user.update_column(:email, Faker::Internet.email)
    user.reload
  end

  def user_without_monitorships
    u = User.includes(:monitorships).find { |x| x.id != @agent.id && x.monitorships.blank? } || add_new_user(@account) # changed as it should have user without any monitorship
    u.update_column(:email, Faker::Internet.email)
    u.reload
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
    comp  = Company.first || create_company
    {
      name: Faker::Lorem.characters(10), address: Faker::Lorem.characters(10),  phone: '1234567892',
      mobile: '1234567893', description: Faker::Lorem.characters(20), email: Faker::Internet.email,  job_title: Faker::Lorem.characters(10),
      language: 'en', time_zone: 'Chennai', company_id: comp.id
    }
  end
end

include Helpers::UsersHelper
