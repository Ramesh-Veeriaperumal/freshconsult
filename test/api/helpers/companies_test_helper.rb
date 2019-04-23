['contact_fields_helper.rb', 'company_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module CompaniesTestHelper
  include ContactFieldsHelper
  include CompanyHelper
  # Patterns

  def company_payload_pattern (expected_output ={}, company)
    domains = company.domains.nil? ? nil : company.domain_list_with_id
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    company_payload_hash = {
      id: Fixnum,
      name: expected_output[:name] || company.name,
      cust_identifier: expected_output[:cust_identifier],
      account_id: expected_output[:account_id] || company.account_id,
      sla_policy_id: expected_output[:sla_policy_id] || company.sla_policy_id,
      delta: expected_output[:delta] || company.delta,
      import_id: expected_output[:import_id] || company.import_id,
      description: company.description,
      domains: expected_output[:domains] || domains,
      note: company.note,
      custom_fields: company.custom_field_hash('company') || company.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v.respond_to?(:utc) ? v.strftime('%F') : v] }.to_h,
      health_score: company.health_score,
      account_tier: company.account_tier,
      industry: company.industry,
      renewal_date: format_renewal_date(company.renewal_date),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      avatar: expected_output[:avatar] || get_contact_avatar(company)
    }
    company_payload_hash
  end

  def company_pattern(expected_output = {}, company)
    domains = company.domains.nil? ? nil : company.domains.split(',')
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    company_hash = {
      id: Fixnum,
      name: expected_output[:name] || company.name,
      description: company.description,
      domains: expected_output[:domains] || domains,
      note: company.note,
      custom_fields: expected_output['custom_field'] || company.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v] }.to_h,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    company_hash
  end

  def public_api_company_pattern(expected_output = {}, company)
    domains = company.domains.nil? ? nil : company.domains.split(',')
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    company_hash = {
      id: Fixnum,
      name: expected_output[:name] || company.name,
      description: company.description,
      domains: expected_output[:domains] || domains,
      note: company.note,
      health_score: company.health_score,
      account_tier: company.account_tier,
      industry: company.industry,
      renewal_date: format_renewal_date(company.renewal_date),
      custom_fields: expected_output['custom_field'] || company.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v] }.to_h,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    company_hash
  end

  def format_renewal_date renewal_date
    renewal_date.respond_to?(:utc) ? renewal_date.utc : renewal_date
  end

  def index_company_pattern(expected_output = {}, company)
    company_pattern(expected_output, company)
  end

  def company_field_pattern(_expected_output = {}, company_field)
    company_field_json = company_field_response_pattern company_field
    if (['default_health_score', 'default_account_tier', 'default_industry', 'custom_dropdown'].include?(company_field.field_type.to_s))
      company_field_json[:choices] = company_field.choices.map { |x| x[:value] }
    end
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

  # Helpers
  def company_payload
    { company: api_company_params }.to_json
  end

  def v2_company_payload
    api_company_params.merge(domains: [Faker::Lorem.characters(5)]).to_json
  end

  def choice_list(company_field)
    case company_field.field_type.to_s
    when 'default_health_score', 'default_account_tier', 'default_industry'
      company_field.choices.map { |x| { label: x[:name], value: x[:value] } }
    when 'custom_dropdown' # not_tested
      company_field.choices.map { |x| { id: x[:id], label: x[:value], value: x[:value] } }
    else
      []
    end
  end

  # private
  def api_company_params
    { name: Faker::Lorem.characters(10),  description: Faker::Lorem.paragraph, domains: Faker::Lorem.characters(5) }
  end
end
