['group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module AgentsTestHelper
  include GroupHelper
  def agent_pattern(expected_output = {}, agent)
    user = {
      active: agent.user.active,
      created_at: agent.user.created_at,
      email: agent.user.email,
      job_title: expected_output['job_title'] || agent.user.job_title,
      language: expected_output['language'] || agent.user.language,
      last_login_at: agent.user.last_login_at.try(:utc).try(:iso8601),
      mobile: expected_output['mobile'] || agent.user.mobile,
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
      signature: expected_output[:signature_html] || agent.signature_html,
      ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
      updated_at: agent.updated_at,
      contact: expected_output[:user] || user
    }
  end

  def private_api_agent_pattern(expected_output = {}, agent)
    {
      
      available: expected_output[:available] || agent.available,
      occasional: expected_output[:occasional] || agent.occasional,
      id: Fixnum,
      ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
      signature: expected_output[:signature_html] || agent.signature_html,
      role_ids: expected_output[:role_ids] || agent.user.role_ids,
      group_ids: expected_output[:group_ids] || agent.group_ids,
      available_since: expected_output[:available_since] || agent.active_since,
      contact: contact_pattern(expected_output[:user] || agent.user),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
      
    }
  end

  def contact_pattern(contact)
    {
      active: contact.active,
      email: contact.email,
      job_title: contact.job_title,
      language: contact.language,
      mobile: contact.mobile,
      name: contact.name,
      phone: contact.phone,
      time_zone: contact.time_zone,
      avatar: get_contact_avatar(contact)
    }
  end

  def get_contact_avatar(contact)
    return nil unless contact.avatar
    {
      content_type: contact.avatar.content_content_type,
      size: contact.avatar.content_file_size,
      name: contact.avatar.content_file_name,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      id: contact.avatar.id,
      attachment_url: String,
      thumb_url: String
    }
  end

  def agent_pattern_with_additional_details(expected_output = {}, agent_user)
    user = {
      active: agent_user.active,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      email: expected_output[:email] || agent_user.email,
      job_title: expected_output[:job_title] || agent_user.job_title,
      language: expected_output[:language] || agent_user.language,
      last_login_at: agent_user.last_login_at.try(:utc).try(:iso8601),
      mobile: expected_output[:mobile] || agent_user.mobile,
      name: expected_output[:name] || agent_user.name,
      phone: expected_output[:phone] || agent_user.phone,
      time_zone: expected_output[:time_zone] || agent_user.time_zone,
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    agent = agent_user.agent
    {
      available_since: expected_output[:available_since] || agent.active_since,
      available: expected_output[:available] || agent.available,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      id: Fixnum,
      occasional: expected_output[:occasional] || agent.occasional,
      signature: expected_output[:signature] || agent.signature_html,
      ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      role_ids: expected_output[:role_ids] || agent_user.role_ids,
      group_ids: expected_output[:group_ids] || agent.group_ids,
      contact: expected_output[:user] || user
    }
  end

  def v2_agent_payload
    role_ids = Role.limit(2).pluck(:id)
    group_ids = [create_group(@account).id]
    params = { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2,
               role_ids: role_ids, job_title: Faker::Name.name }
    params.to_json
  end

  def v1_agent_payload
    role_ids = Role.limit(2).pluck(:id).join(',')
    params = { agent: { user: { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, job_title: Faker::Name.name, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', role_ids: role_ids }, occasional: false, signature_html: Faker::Lorem.paragraph, ticket_permission: 2 } }
    params.to_json
  end
end
