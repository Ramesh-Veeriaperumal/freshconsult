module Admin::ConditionValidationHelper
  include Admin::CustomFieldHelper
  include Admin::ConditionErrorHelper

  def initialize_params(request_params, default_fields, custom_fields, rule_type)
    @rule_type = rule_type.to_i
    cf_names = custom_fields.first.to_a
    create_attr_accessor_for_cf(cf_names)
    self.custom_field_hash = custom_fields[1]
    set_params(request_params, default_fields + cf_names)
  end

  def set_params(request_params, valid_attributes)
    format_params = {}
    @invalid_attributes = []
    request_params.each do |param|
      next if param[:field_name].blank?
      if valid_attributes.include?(param[:field_name].to_sym)
        format_params[param[:field_name]] ||= []
        format_params[param[:field_name]] << param
      else
        next if param[:field_name].start_with?('cf_')

        custom_field_name = 'cf_' + param[:field_name]
        if valid_attributes.include?(custom_field_name.to_sym)
          param[:field_name] = custom_field_name
          format_params[param[:field_name]] ||= []
          format_params[param[:field_name]] << param
        else
          @invalid_attributes << param[:field_name]
        end
      end
    end
    format_params
  end

  def create_attr_accessor_for_cf(cf_names)
    cf_names ||= []
    cf_names.each do |name|
      self.class.safe_send(:attr_accessor, name)
    end
  end

  def attribute_type(attributes)
    attributes.each do |item|
      attribute_value = safe_send(item[:name])
      next if attribute_value.blank?
      if invalid_attribute_for_rule?(item[:invalid_rule_types])
        unexpected_parameter(item[:name])
        next
      end
      execute_field_validation(item, attribute_value)
    end
  end

  def invalid_attribute_for_rule?(invalid_rule_types)
    invalid_rule_types.is_a?(Array) && invalid_rule_types.include?(@rule_type)
  end

  def execute_field_validation(field_hash, fields)
    @field_position = 1
    fields.each do |each_attribute|
      if @field_position > 1 && field_hash[:non_unique_field]
        not_allowed_error(field_hash[:name], :non_unique_field_automation)
        next
      end
      safe_send(:"#{validator_type}_validation", field_hash, each_attribute)
      @field_position += 1
    end
  end

  def validate_label_field_type(expected, actual)
    if actual[:from].present? || actual[:to].present? || actual[:value].present?
      invalid_values = []
      invalid_values << :from if actual.key? :from
      invalid_values << :to if actual.key? :to
      invalid_values << :value if actual.key? :value
      unexpected_value_for_attribute(expected[:name], invalid_values.join(','))
    end
  end

  def validate_email(name, emails)
    emails = *emails
    invalid_list = []
    emails.each do |email|
      invalid_list << email unless email.match(ApiConstants::EMAIL_REGEX)
    end
    invalid_email_addresses(name, invalid_list) if invalid_list.present?
  end

  def validate_date(name, date)
    date = date.split('-')
    unexpected_parameter(name) unless Date.valid_date?(date[0].to_i, date[1].to_i, date[2].to_i)
  end

  def validate_business_hours(name, actual)
    if actual.key?(:business_hours_id)
      multiple_business_hours?
      missing_field_error(name, :business_hours_id) if actual[:business_hours_id].blank?
      invalid_data_type(name, :Number, :invalid) unless actual[:business_hours_id].is_a?(Integer)
    end
  end

  def fetch_missing_fields(expected, actual)
    missing_fields = []
    expected.each { |field| missing_fields << field unless actual.include? field }
    missing_fields
  end

  def validate_default_conditions_params(condition_set, set)
    validate_match_type(condition_set[:name], condition_set[:match_type])
    properties = condition_set[:properties]
    not_allowed_error("[:condition_set_#{set}][:properties]", :cannot_be_blank) && return if properties.blank?

    invalid_data_type("[:condition_set_#{set}][:properties]", Array, properties.inspect) && return unless properties.is_a?(Array)

    resource_types = properties.map { |cond| cond[:resource_type].try(:to_sym) }
    validate_resource_types(resource_types)
    validate_condition_properties(properties, set)
  end

  def validate_condition_properties(properties, set)
    properties.each do |property|
      expected_fields = expected_properties_fields(property[:field_name], property[:resource_type])
      fetch_missing_fields(expected_fields, property.keys.map(&:to_sym)).each do |missing_field|
        missing_field_error("[#{property[:field_name]}]", missing_field)
      end
      invalid_data_type("condition_set_#{set}[:nested_fields]", Hash, :invalid) && break if
          !property[:nested_fields].is_a?(Hash) && property[:nested_fields].present?
      property[:nested_fields].each_pair do |level_key, level_value|
        unexpected_parameter("condition_set_#{set}[:nested_fields][#{level_key}") unless LEVELS.include?(level_key.to_sym)
        fetch_missing_fields(PERMITTED_DEFAULT_CONDITION_SET_VALUES, level_value.keys.map(&:to_sym)).each do |missing_field|
          missing_field_error("condition_set_#{set}[:#{property[:field_name]}][:#{level_key}]", missing_field)
        end
      end if property.key?(:nested_fields) && property[:nested_fields].is_a?(Hash)
    end
  end

  def expected_properties_fields(field_name, evaluate_on)
    property_field_name = evaluate_on.try(:to_sym) != :ticket ? "cf_#{field_name}" : "#{field_name}_#{Account.current.id}"
    is_checkbox = case evaluate_on.try(:to_sym)
                  when :contact
                    contact_form_fields.find { |conf| conf.name == property_field_name }.try(:custom_checkbox_field?) || default_contact_checkbox?(field_name)
                  when :company
                    company_form_fields.find { |conf| conf.name == property_field_name }.try(:custom_checkbox_field?)
                  else
                    Account.current.ticket_fields_from_cache.find { |tf| tf.name == property_field_name }.try(:custom_checkbox_field?)
                  end
    is_checkbox ? CONDITION_SET_PROPERTIES - %i[value] : CONDITION_SET_PROPERTIES
  end

  def default_contact_checkbox?(field_name)
    contact_field = CONDITION_CONTACT_FIELDS_HASH.find { |field| field if field[:name].to_s == field_name }
    return contact_field[:field_type].to_s == 'checkbox' if contact_field

    false
  end

  def validate_condition_set_names(condition_names)
    expected_names = supervisor_rule? ? CONDITION_SET_NAMES.first.to_a : CONDITION_SET_NAMES
    valid_condition_set_count?
    condition_names.each_with_index do |condition_name, index|
      self.type_name = "conditions[:conditions_set_#{index + 1}]".to_sym
      not_included_error(condition_name.to_sym, expected_names) unless expected_names.include?(condition_name)
    end
    not_allowed_error(condition_names[0],
                      :duplicate_condition_set_name) if condition_names[0] == condition_names[1] && condition_names.size == 2
  end

  def valid_condition_set_count?
    valid_set_count = supervisor_rule? ? MAXIMUM_SUPERVISOR_CONDITION_SET_COUNT : MAXIMUM_CONDITION_SET_COUNT
    invalid_condition_set_count(valid_set_count) if conditions.size > valid_set_count
  end

  def validate_condition_set_operator(operator, conditions_count, update_call = false)
    valid_operators = CONDITION_SET_OPERATOR.map { |op| "condition_set_1 #{op} condition_set_2" }
    case true
    when update_call
      condition_sets_size = fetch_condition_set_size(conditions_count)
      validate_condition_set_operator(operator, condition_sets_size)
    when conditions_count > 1 && operator.blank?
      missing_field_error(:operator, 'operator')
    when operator.present? && (0..1).to_a.include?(conditions_count)
      unexpected_parameter(:operator, :condition_set_operator_error)
    when valid_operators.exclude?(operator) && operator.present?
      not_included_error(:operator, valid_operators)
    end
  end

  def validate_match_type(name, match_type)
    unless Admin::AutomationConstants::MATCH_TYPE.include?(match_type)
      self.type_name = "conditions[#{name}]".to_sym
      invalid_value_list(:match_type, Admin::AutomationConstants::MATCH_TYPE)
    end
  end

  def validate_resource_types(resource_type)
    expected_resource_types = supervisor_rule? ? %i[ticket] : CONDITION_RESOURCE_TYPES
    unless resource_type & expected_resource_types == resource_type
      self.type_name = 'conditions[:resource_type]'
      invalid_resources = resource_type - expected_resource_types
      invalid_resources.each do |invalid_resource|
        next if invalid_resource.blank?

        not_included_error(invalid_resource.to_sym, expected_resource_types.map(&:to_s))
      end
    end
  end

  def construct_condition_validation_params(condition_sets, resource_type)
    result = []
    condition_sets.map do |condition_set|
      cond = { field_name: condition_set[:field_name], operator: condition_set[:operator] }
      %i[value nested_fields related_conditions].each { |key| cond[key] = condition_set[key] if condition_set.key? key }
      result << cond if (condition_set[:resource_type].try(:to_sym) || :ticket) == resource_type
    end
    result
  end

  def validate_conditions_properties(set, field_type, condition_sets)
    validate_class = "Admin::AutomationRules::Conditions::#{field_type.to_s.camelcase}Validation".constantize
    additional_options = { events: events, performer: performer }
    condition_validation = validate_class.new(condition_sets, safe_send(:"custom_#{field_type}_condition"), set,
                                              rule_type, additional_options)
    is_valid = condition_validation.valid?(validation_context)
    unless is_valid
      merge_to_parent_errors(condition_validation)
      error_options.merge! condition_validation.error_options
    end
  end

  def fetch_condition_set_size(conditions_count)
    case true
    when supervisor_rule?
      1
    when conditions_count.blank?
      rule_association = "all_#{VAConfig::ASSOCIATION_MAPPING[VAConfig::RULES_BY_ID[@request_params[:rule_type].to_i]]}"
      condition_data = Account.current.safe_send(rule_association).find(@request_params[:id]).condition_data
      conditions = observer_rule? ? condition_data[:conditions] : condition_data
      size = if conditions_present?(conditions)
               single_set?(conditions) ? 1 : 2
             else
               0
             end
      size
    else
      @request_params[:conditions].count
    end
  end

  def conditions_present?(conditions)
    conditions.first[1].first.present?
  end

  def single_set?(conditions)
    conditions.first[1].first.key?(:evaluate_on)
  end

  def company_form_fields
    @company_form_fields ||= Account.current.company_form.company_fields_from_cache
  end

  def contact_form_fields
    @contact_form_fields ||= Account.current.contact_form.contact_fields_from_cache
  end

  def validate_association_type(name, actual)
    allowed_types = dispatcher_rule? ? DISPATCHER_CONDITION_TICKET_ASSOCIATION_TYPES : TICKET_ASSOCIATION_TYPES
    not_included_error(name, allowed_types) unless allowed_types.include?(actual[:value])
  end

  def none_value?(value, is_none_field)
    value == '' && is_none_field
  end

  def any_value?(value, is_any_field)
    value == '--' && is_any_field
  end

  def any_none_value?(value, is_any_none)
    ANY_NONE_VALUES.include?(value) && is_any_none
  end

  def dispatcher_rule?
    VAConfig::DISPATCHER_RULE_TYPES.include?(rule_type.to_i)
  end

  def observer_rule?
    VAConfig::OBSERVER_RULE_TYPES.include?(rule_type.to_i)
  end

  def supervisor_rule?
    rule_name = VAConfig::RULES_BY_ID[rule_type.to_i]
    rule_name == :supervisor
  end

  def add_watcher_feature
    unless current_account.add_watcher_enabled?
      errors[:"watcher[:condition]"] << :require_feature
      error_options.merge!(:"watcher[:condition]" => {feature: :add_watcher,
                                                      code: :access_denied})
    end
  end

  def multi_product_feature
    unless current_account.multi_product_enabled?
      errors[:"multi_product[:condition]"] << :require_feature
      error_options.merge!(:"multi_product[:condition]" => {feature: :multi_product,
                                                            code: :access_denied})
    end
  end

  def shared_ownership_feature
    unless current_account.shared_ownership_enabled?
      errors[:"shared_ownership[:condition]"] << :require_feature
      error_options.merge!(:"shared_ownership[:condition]" => {feature: :shared_ownership,
                                                               code: :access_denied})
    end
  end

  def multiple_business_hours?
    unless current_account.multiple_business_hours_enabled?
      errors[:"multiple_business_hours[:condition]"] << :require_feature
      error_options.merge!(:"multiple_business_hours[:condition]" => {feature: :multiple_business_hours,
                                                                      code: :access_denied})
    end
  end

  def system_observer_events
    unless current_account.system_observer_events_enabled?
      errors[:condition] << :require_feature
      error_options.merge!(condition: {feature: :system_observer_events,
                                       code: :access_denied})
    end
  end

  def custom_survey_feature
    unless current_account.any_survey_feature_enabled_and_active?
      errors[:"any_survey[:condition]"] << :require_feature
      error_options.merge!(:"any_survey[:condition]" => {feature: :survey, # I am not sure about the feature please check
                                                         code: :access_denied})
    end
  end

  def supervisor_text_field?
    unless current_account.supervisor_text_field_enabled?
      errors[:"supervisor_text_field[:condition]"] << :require_feature
      error_options.merge!(:"supervisor_text_field[:condition]" => {feature: :supervisor_text_field, # I am not sure about the feature please check
                                                         code: :access_denied})
    end
  end

  def detect_thank_you_note_feature
    unless current_account.detect_thank_you_note_enabled?
      errors[:"freddy_suggestion[:condition]"] << :require_feature
      error_options.merge!("freddy_suggestion[:condition]": { feature: :detect_thank_you_note,
                                                              code: :access_denied })
    end
  end

  def current_account
    @current_account ||= Account.current
  end
end
