module VA::Search::VaRuleSearchTransformer
  include VA::Search::Constants

  def construct_search_hash(data)
    name = data[:name].to_sym
    if AUTOMATIONS_SEARCH_FIELDS[type][:fields_with_filter_search].include?(name)
      transform_fields(name, data, construct_default_hash(data))
    elsif AUTOMATIONS_SEARCH_FIELDS[type][:fields_without_filter_search].include?(name)
      transform_non_searchable_value(data)
    else
      custom_field = fetch_custom_field(name)
      transform_custom_fields(custom_field, data) if custom_field.present?
    end
  end

  def transform_fields(name, data, default_hash)
    if data[:value].present?
      handle_value(data[:value], name).map do |val|
        transformed_hash = default_hash.merge(value: construct_search_value(name, val))
        CONDITIONS_ADDITIONAL_FIELDS.each do |addition_field|
          transformed_hash[addition_field] = data[addition_field] if data.key?(addition_field)
        end
        transformed_hash
      end
    else
      [default_hash]
    end
  end

  def transform_custom_fields(custom_field, data)
    name = data[:name].to_sym
    default_hash = construct_default_hash(data, name: custom_field.name)

    case custom_field.dom_type.to_sym
    when :text, :paragraph, :encrypted_text, :url
      transform_non_searchable_value(default_hash)
    when :checkbox, :number, :date, :decimal, :phone_number
      transform_fields(name, data, default_hash)
    when :nested_field
      transform_nested_field(custom_field, data)
    when :dropdown_blank
      transform_custom_dropdown(custom_field, data, default_hash)
    end
  end

  def transform_custom_dropdown(custom_field, data, default_hash)
    custom_dropdown_values(custom_field, data[:value]).map { |id| default_hash.merge(value: id) }
  end

  def transform_nested_field(ticket_field, data)
    transformed_nested_field = []
    default_hash = construct_default_hash(data, name: ticket_field.name)
    if ANY_NONE_VALUES.include? data[:value]
      transformed_nested_field.push(default_hash.merge(value: DEFAULT_ANY_NONE[data[:value]]))
      return transformed_nested_field
    end

    picklists = ticket_field.picklist_values.find_all_by_value(data[:value])
    picklists.each { |picklist| transformed_nested_field.push(default_hash.merge(value: picklist.try(:picklist_id))) }

    data[:nested_rules].each do |nested_rule|
      nested_rule.deep_symbolize_keys
      default_hash = construct_default_hash(nested_rule, evaluate_on: data[:evaluate_on])
      any_none_included = ANY_NONE_VALUES.include? nested_rule[:value]
      transformed_nested_field.push(default_hash.merge(value: DEFAULT_ANY_NONE[nested_rule[:value]])) && break if any_none_included
      picklists = find_sub_picklist_by_value(picklists.try(:first), nested_rule[:value])
      picklists.each { |picklist| transformed_nested_field.push(default_hash.merge(value: picklist.try(:picklist_id))) }
      break if picklists.count > 1
    end
    transformed_nested_field
  end

  def construct_search_value(name, value)
    if ANY_NONE_VALUES.include?(value)
      value = DEFAULT_ANY_NONE[value]
    elsif AUTOMATIONS_SEARCH_FIELDS[type][:transformable_fields].include?(name)
      value = safe_send("#{name}_id", value)
    end
    value
  end

  def fetch_custom_field(name)
    custom_ticket_fields.find { |t| t.name == name.to_s }
  end

  def construct_default_hash(data, translated_values = {})
    name = display_name(translated_values[:name] || data[:name])
    { name: name }
  end

  def display_name(name)
    if FIELD_VALUE_CHANGE_MAPPING.key? name.to_sym
      FIELD_VALUE_CHANGE_MAPPING[name.to_sym]
    elsif name.to_s.ends_with?("_#{current_account.id}")
      TicketDecorator.display_name(name)
    else
      name
    end
  end

  def custom_dropdown_values(custom_field, values)
    values = handle_value(values)
    values, picklist_ids = handle_any_none_values(values)
    picklist_ids.push(*custom_field.picklist_values.where(value: values).pluck(:picklist_id)) if values.count > 0
    picklist_ids
  end

  def handle_any_none_values(values)
    values_with_none = values & ANY_NONE_VALUES
    choices = values_with_none.map { |val| DEFAULT_ANY_NONE[val] } || []
    [(values - ANY_NONE_VALUES), choices]
  end

  def transform_non_searchable_value(data)
    [{ name: data[:name], value: :present }]
  end

  private

    def find_sub_picklist_by_value(picklist, value)
      picklist.sub_picklist_values.find_all_by_value(value)
    end

    def handle_value(value, field_name = nil)
      [*value]
    end

    def custom_ticket_fields
      @custom_ticket_fields ||= current_account.ticket_fields_from_cache
    end

    def company_form
      @company_form ||= current_account.company_form
    end

    def company_form_fields
      @company_form_fields ||= company_form.company_fields_from_cache
    end

    def contact_form
      @contact_form ||= current_account.contact_form
    end

    def contact_form_fields
      @contact_form_fields ||= contact_form.contact_fields_from_cache
    end

    def company_field_choices(field_type)
      company_form.default_drop_down_fields(field_type.to_sym)
                  .first.custom_field_choices.each.inject({}) { |hash, c| hash.merge(c.value => c.id) }
    end

    def health_score
      @health_score ||= company_field_choices(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:health_score])
    end

    def health_score_id(value)
      health_score[value]
    end

    def account_tier
      @account_tier ||= company_field_choices(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:account_tier])
    end

    def account_tier_id(value)
      account_tier[value]
    end

    def industry
      @industry ||= company_field_choices(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:industry])
    end

    def ticket_type_id(value)
      ticket_type = ticket_types.find { |x| x.value == value }
      ticket_type.try(:id)
    end

    def ticket_types
      @ticket_types ||= current_account.ticket_types_from_cache
    end

    def add_tag_id(value)
      current_account.tags.find_by_name(value).try(:id)
    end

    def industry_id(value)
      industry[value]
    end

    def current_account
      @current_account ||= Account.current
    end
end
