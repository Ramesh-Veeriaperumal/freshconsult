module Proactive::RuleFiltersConcern
  extend ActiveSupport::Concern
  include ::Proactive::Constants

  def add_contact_fields(filter_hash)
    email_hash = if private_api?
                   { name: 'email',
                     type: 'text', operations: TEXT_OPERATIONS,
                     auto_complete: true, data_url: requesters_search_autocomplete_index_path }
                 else
                   { name: 'email',
                     type: 'text', operations: TEXT_OPERATIONS }
                 end

    filter_hash['contact_fields'] = [
      email_hash,
      { name: 'name', type: 'text',
        operations: TEXT_OPERATIONS },
      { name: 'job_title', type: 'text',
        operations: TEXT_OPERATIONS }
    ]

    if multi_timezone_account?
      filter_hash['contact_fields'].push(
        name: 'time_zone', type: 'multi_text',
        choices: TIMEZONES_AVAILABLE,
        operations: MULTI_TEXT_OPERATIONS
      )
    end

    if multi_language_account?
      filter_hash['contact_fields'].push(
        name: 'language', type: 'multi_text',
        choices: LOCALES_AVAILABLE, operations: MULTI_TEXT_OPERATIONS
      )
    end

    add_customer_custom_fields filter_hash['contact_fields'], 'contact'
  end

  def add_company_fields(filter_hash)
    name_hash = if private_api?
                  { name: 'name', type: 'multi_text',
                    operations: MULTI_TEXT_OPERATIONS,
                    auto_complete: true, data_url: companies_search_autocomplete_index_path }
                else
                  { name: 'name', type: 'multi_text',
                    operations: MULTI_TEXT_OPERATIONS }
                end
    filter_hash['company_fields'] = [
      name_hash,
      { name: 'domains', type: 'multi_text',
        operations: TAG_OPERATIONS }
    ]
    add_tam_company_fields filter_hash['company_fields'] if current_account.tam_default_fields_enabled?
    add_customer_custom_fields filter_hash['company_fields'], 'company'
  end

  def add_customer_custom_fields(filter_hash, type)
    cf = current_account.safe_send("#{type}_form").safe_send("custom_#{type}_fields")
    if cf.present?
      cf.each do |field|
        custom_hash = {
          name: field.name.to_s,
          label: field.label,
          type: CF_TYPES.fetch(field.field_type.to_s),
          operations: CF_CUSTOMER_MAPPING.fetch(field.field_type.to_s)
        }
        if CF_TYPES.fetch(field.field_type.to_s) == 'multi_text'
          custom_hash.merge!(
            choices: field.custom_field_choices.collect { |c| { name: c.value, label: c.value } }
          )
        end
        filter_hash.push(custom_hash)
      end
    end
  end

  def add_tam_company_fields(filter_hash)
    filter_hash.push(
      { name: 'health_score', type: 'multi_text',
        choices: company_field_choices(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:health_score]),
        operations: MULTI_TEXT_OPERATIONS },
      { name: 'account_tier', type: 'multi_text',
        choices: company_field_choices(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:account_tier]),
        operations: MULTI_TEXT_OPERATIONS },
      { name: 'industry', type: 'multi_text',
        choices: company_field_choices(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:industry]),
        operations: MULTI_TEXT_OPERATIONS },
      { name: 'renewal_date', type: 'date',
        operations: DATE_OPERATIONS }
    )
  end

  def multi_timezone_account?
    current_account.multi_timezone_enabled?
  end

  def multi_language_account?
    current_account.features?(:multi_language)
  end

  def company_field_choices(field_type)
    current_account.company_form.default_drop_down_fields(field_type.to_sym)
                   .first.custom_field_choices.collect { |c| { name: c.id, label: CGI.unescapeHTML(c.value) } }
  end
end
