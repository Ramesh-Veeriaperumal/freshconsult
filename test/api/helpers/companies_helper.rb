module Helpers::CompaniesHelper
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
      domains: domains,
      note: company.note,
      custom_fields: company.custom_field,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def company_field_pattern(_expected_output = {}, company_field)
    company_field_json = company_field_response_pattern company_field
    company_field_json[:choices] = company_field.choices.map { |x| x[:value] } if company_field.field_type.to_s == 'custom_dropdown'
    company_field_json
  end

  def company_field_response_pattern(company_field)
    {
      id: Fixnum,
      name: company_field.name,
      default: company_field.default_field?,
      label: company_field.label,
      field_type: company_field.field_type,
      position: company_field.position,
      required_for_agent: company_field.required_for_agent,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
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
