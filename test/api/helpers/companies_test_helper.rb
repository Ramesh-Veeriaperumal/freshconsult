['contact_fields_helper.rb', 'company_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module CompaniesTestHelper
  include ContactFieldsHelper
  include CompanyHelper
  # Patterns
  def company_pattern(expected_output = {}, company)
    domains = company.domains.nil? ? nil : company.domains.split(',')
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: expected_output[:name] || company.name,
      description: company.description,
      domains: expected_output[:domains] || domains,
      note: company.note,
      custom_fields: expected_output['custom_field'] || company.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v] }.to_h,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def company_show_pattern(expected_output = {}, company)
    response_pattern = company_pattern(expected_output, company)
    sla_array = []
    (expected_output[:sla_policies] || []).each do |sla_policy|
      sla_array << sla_policy_pattern(sla_policy)
    end
    response_pattern.merge!(sla_policies: sla_array)
    response_pattern
  end

  def company_pattern_with_associations(expected_output = {}, company, include_options)
    response_pattern = company_pattern(expected_output, company)
    if include_options.include?('contacts_count')
      response_pattern.merge!(contacts_count: company.users.count)
    end
    response_pattern
  end

  def company_field_pattern(_expected_output = {}, company_field)
    company_field_json = company_field_response_pattern company_field
    company_field_json[:choices] = company_field.choices.map { |x| x[:value] } if company_field.field_type.to_s == 'custom_dropdown'
    company_field_json
  end

  def company_field_response_pattern(company_field)
    {
      id: Fixnum,
      name: company_field.default_field? ? company_field.name : company_field.name[3..-1],
      default: company_field.default_field?,
      label: company_field.label,
      type: company_field.field_type.to_s,
      position: company_field.position,
      required_for_agent: company_field.required_for_agent,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def company_activity_pattern(ticket)
    {
      id: ticket.display_id,
      subject: ticket.subject,
      status: ticket.status,
      agent_id: ticket.responder_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  # Helpers
  def company_payload
    { company: api_company_params }.to_json
  end

  def v2_company_payload
    api_company_params.merge(domains: [Faker::Lorem.characters(5)]).to_json
  end

  # private
  def api_company_params
    { name: Faker::Lorem.characters(10),  description: Faker::Lorem.paragraph, domains: Faker::Lorem.characters(5) }
  end
end
