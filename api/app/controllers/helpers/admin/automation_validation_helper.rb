module Admin::AutomationValidationHelper
  include Admin::AutomationConstants
  include Admin::Automation::CustomFieldHelper
  include Admin::AutomationErrorHelper

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
        @invalid_attributes << param[:field_name]
      end
    end
    format_params
  end

  def create_attr_accessor_for_cf(cf_names)
    cf_names ||= []
    cf_names.each do |name|
      self.class.send(:attr_accessor, name)
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
    invalid_rule_types.include?(@rule_type)
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
    rule_name = VAConfig::RULES_BY_ID[rule_type.to_i]
    rule_name == :dispatcher
  end

  def observer_rule?
    rule_name = VAConfig::RULES_BY_ID[rule_type.to_i]
    rule_name == :observer
  end

  def supervisor_rule?
    rule_name = VAConfig::RULES_BY_ID[rule_type.to_i]
    rule_name == :supervisor
  end

  def add_watcher_feature
    unless Account.current.add_watcher_enabled?
      errors[:"watcher[:condition]"] << :require_feature
      error_options.merge!(:"watcher[:condition]" => {feature: :add_watcher,
                                                      code: :access_denied})
    end
  end

  def multi_product_feature
    unless Account.current.multi_product_enabled?
      errors[:"multi_product[:condition]"] << :require_feature
      error_options.merge!(:"multi_product[:condition]" => {feature: :multi_product,
                                                            code: :access_denied})
    end
  end

  def shared_ownership_feature
    unless Account.current.shared_ownership_enabled?
      errors[:"shared_ownership[:condition]"] << :require_feature
      error_options.merge!(:"shared_ownership[:condition]" => {feature: :shared_ownership,
                                                               code: :access_denied})
    end
  end

  def multiple_business_hours?
    unless Account.current.multiple_business_hours_enabled?
      errors[:"multiple_business_hours[:condition]"] << :require_feature
      error_options.merge!(:"multiple_business_hours[:condition]" => {feature: :multiple_business_hours,
                                                                      code: :access_denied})
    end
  end

  def system_observer_events
    unless Account.current.system_observer_events_enabled?
      errors[:condition] << :require_feature
      error_options.merge!(condition: {feature: :system_observer_events,
                                       code: :access_denied})
    end
  end

  def custom_survey_feature
    unless Account.current.any_survey_feature_enabled_and_active?
      errors[:"any_survey[:condition]"] << :require_feature
      error_options.merge!(:"any_survey[:condition]" => {feature: :survey, # I am not sure about the feature please check
                                                         code: :access_denied})
    end
  end

  def supervisor_text_field?
    unless Account.current.supervisor_text_field_enabled?
      errors[:"supervisor_text_field[:condition]"] << :require_feature
      error_options.merge!(:"supervisor_text_field[:condition]" => {feature: :supervisor_text_field, # I am not sure about the feature please check
                                                         code: :access_denied})
    end
  end

  def detect_thank_you_note_feature
    unless Account.current.detect_thank_you_note_enabled?
      errors[:"freddy_suggestion[:condition]"] << :require_feature
      error_options.merge!("freddy_suggestion[:condition]": { feature: :detect_thank_you_note,
                                                              code: :access_denied })
    end
  end
end
