['company_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['contact_fields_helper.rb', 'company_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['attachments_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['company_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }
module CompaniesTestHelper
  include ContactFieldsHelper
  include ApiCompanyHelper
  include AttachmentsTestHelper
  # Patterns

  def company_payload_pattern (expected_output ={}, company)
    domains = company.domains.nil? ? nil : company.domains.split(',')
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
      custom_fields: company.custom_fields_hash || company.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v.respond_to?(:utc) ? v.strftime('%F') : v] }.to_h,
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
      custom_fields: expected_output['custom_field'] || company.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v.respond_to?(:utc) ? v.strftime('%F') : v] }.to_h,
      health_score: company.health_score,
      account_tier: company.account_tier,
      industry: company.industry,
      renewal_date: format_renewal_date(company.renewal_date),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      avatar: expected_output[:avatar] || get_contact_avatar(company)
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

  def v2_company_pattern(expected_output = {}, company)
    domains = company.domains.nil? ? nil : company.domains.split(',')
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: expected_output[:name] || company.name,
      description: company.description,
      domains: expected_output[:domains] || domains,
      note: company.note,
      health_score: company.health_score,
      account_tier: company.account_tier,
      industry: company.industry,
      renewal_date: format_renewal_date(company.renewal_date),
      custom_fields: expected_output['custom_field'] || company.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v.respond_to?(:utc) ? v.strftime('%F') : v] }.to_h,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def get_contact_avatar(company)
    return nil unless company.avatar
    company_avatar = {
      content_type: company.avatar.content_content_type,
      size: company.avatar.content_file_size,
      name: company.avatar.content_file_name,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      id: company.avatar.id
    }
    if @private_api
      company_avatar[:attachment_url] = String
      company_avatar[:thumb_url] = String
    else
      company_avatar[:avatar_url] = String
    end
    company_avatar
  end

  def add_avatar_to_company(company)
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
    company.build_avatar(
      content: file,
      description: Faker::Lorem.characters(10),
      account_id: @account.id
    )
    company.save
  end

  def index_company_pattern(expected_output = {}, include_options = [])
    pattern = []
    companies = include_options.blank? ? Account.current.companies.order(:name).limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]) :
      Account.current.companies.preload(:user_companies).order(:name).limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    companies.all.each do |company|
      pattern << company_pattern_with_associations(expected_output,
                                                   company, include_options)
    end
    pattern
  end

  def company_show_pattern(expected_output = {}, company)
    response_pattern = company_pattern(expected_output, company)
    sla_array = []
    (expected_output[:sla_policies] || []).each do |sla_policy|
      sla_array << sla_policy_private_pattern(sla_policy)
    end
    response_pattern[:sla_policies] = sla_array
    response_pattern
  end

  def company_pattern_with_associations(expected_output = {}, company, include_options)
    response_pattern = company_pattern(expected_output, company)
    if include_options.include?('contacts_count')
      response_pattern[:contacts_count] = company.users.count
    end
    response_pattern
  end

  # def index_company_pattern(expected_output = {}, company)
  #   company_pattern(expected_output, company)
  # end

  def company_field_pattern(_expected_output = {}, company_field)
    company_field_json = company_field_response_pattern company_field
    unless company_field.choices.blank?
      if @private_api
        company_field_json[:choices] = choice_list(company_field)
      else
        if (['default_health_score', 'default_account_tier', 'default_industry', 'custom_dropdown'].include?(company_field.field_type.to_s))
          company_field_json[:choices] = company_field.choices.map { |x| x[:value] }
        end
      end
    end
    company_field_json
  end

  def private_company_field_pattern(expected_output = {}, company_field)
    result = company_field_pattern(expected_output, company_field).except(:created_at, :updated_at)
    result[:widget_position] = company_field.field_options.present? ? company_field.field_options['widget_position'] : nil
    result
  end

  def company_field_response_pattern(company_field)
    {
      id: Fixnum,
      name: company_field.default_field? ? company_field.name : company_field.name[3..-1],
      default: company_field.default_field?,
      label: company_field.label,
      type: company_field.field_type.to_s,
      position: company_field.position,
      required_for_agents: company_field.required_for_agent,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def company_activity_response(objects, _meta = false)
    response_pattern = {}
    objects.map do |item|
      archived?(item) ? type = "ticket" : type = item.class.name.gsub('Helpdesk::', '').downcase
      to_ret = company_activity_pattern(item)
      (response_pattern[type.to_sym] ||= []).push to_ret
    end
    response_pattern
  end
    
  def company_activity_pattern(obj)
    ret_hash = {
      id: obj.display_id,
      responder_id: obj.responder_id,
      subject: obj.subject,
      requester_id: obj.requester_id,
      group_id: obj.group_id,
      source: obj.source,
      created_at: obj.created_at.try(:utc)
    }
    ret_hash.merge!(whitelisted_properties_for_activities(obj))
    ret_hash
  end
  
  def whitelisted_properties_for_activities(obj)
    return {archived: true} if archived?(obj)
    {
      description_text: obj.description,
      due_by: obj.due_by.try(:utc),
      stats: stats(obj),
      fr_due_by: obj.frDueBy.try(:utc),
      tags: obj.tag_names,
      status: obj.status
    }
  end


  def parse_time(attribute)
    attribute ? Time.parse(attribute).utc : nil
  end

  def archived?(obj)
    @is_archived ||= obj.is_a?(Helpdesk::ArchiveTicket)
  end

  def stats(obj)
    ticket_states = obj.ticket_states
    {
      agent_responded_at: ticket_states.agent_responded_at.try(:utc),
      requester_responded_at: ticket_states.requester_responded_at.try(:utc),
      resolved_at: ticket_states.resolved_at.try(:utc),
      first_responded_at: ticket_states.first_response_time.try(:utc),
      closed_at: ticket_states.closed_at.try(:utc),
      status_updated_at: ticket_states.status_updated_at.try(:utc),
      pending_since: ticket_states.pending_since.try(:utc),
      reopened_at: ticket_states.opened_at.try(:utc)
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
    { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, domains: Faker::Lorem.characters(5) }
  end
end
