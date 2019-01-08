class ProactiveRuleDelegator < BaseDelegator

  include ::Proactive::Constants

  validate :condition_field_validation, unless: -> { @filter.blank? } 

  def initialize(record, options)
    super(record, options)
    @filter = options[:filter]
    @conditions = options[:conditions]
    @contact_fields = options[:contact_fields]
    @company_fields = options[:company_fields]
  end


  def condition_field_validation
    @contact_fields = build_contact_field_hash
    @company_fields = build_company_field_hash
    @conditions.each do |condition|
      break unless check_filter_errors?
      validate_entity(condition[:entity])
      if check_filter_errors? && condition[:entity] == ALLOWED_ENTITIES[0]
        validate_field_name(condition[:field], @contact_fields)
        validate_field_attr(condition, @contact_fields[condition[:field]]) if check_filter_errors?
      elsif check_filter_errors? && condition[:entity] == ALLOWED_ENTITIES[1]
        validate_field_name(condition[:field], @company_fields)
        validate_field_attr(condition, @company_fields[condition[:field]]) if check_filter_errors?
      end
    end
  end

  def validate_entity(entity)
    unless ALLOWED_ENTITIES.include?(entity)
      errors[:filter] = :not_included
      (error_options[:filter] ||= {}).merge!(list: ALLOWED_ENTITIES.join(", "), nested_field: "conditions.#{entity}", code: :invalid_value)
    end
  end

  def validate_field_name(input_field, entity_fields)
    if entity_fields[input_field].nil?
      errors[:filter] = :not_included
      (error_options[:filter] ||= {}).merge!(list: entity_fields.keys.join(", "), nested_field: "conditions.#{input_field}", code: :invalid_value)
    end
  end

  def validate_field_attr(condition, field_properties)
    check_allowed_operations(condition[:operator], field_properties[:operations], condition[:field])
    check_field_value_types(condition[:value], field_properties[:type]) if check_filter_errors?
    check_field_values(condition[:value], field_properties[:choices], condition[:field], field_properties[:type]) if field_properties.key?(:choices) && check_filter_errors?
  end

  def check_allowed_operations(input_op, allowed_ops, field_name)
    unless allowed_ops.include?(input_op)
      errors[:filter] = :not_included
      (error_options[:filter] ||= {}).merge!(list: allowed_ops.join(", "), nested_field: "conditions.#{field_name}.#{input_op}", code: :invalid_value)
    end
  end

  def check_field_value_types(value, type)
    if %w[number decimal].include?(type) && !numeric?(value)
      build_in_valid_data_type_error("Number/Decimal")
    elsif %w[text paragraph].include?(type) && !value.is_a?(String)
      build_in_valid_data_type_error("String")
    elsif type == "multi_text" && !value.is_a?(Array)
      build_in_valid_data_type_error("Array")
    elsif type == "boolean" && !check_valid_boolean(value)
      build_in_valid_data_type_error("Boolean")
    elsif type == "date" && invalid_date?(value, false)
      build_in_valid_data_type_error("Date")
    end
  end

  def build_in_valid_data_type_error(data_type)
    errors[:filter] = :datatype_mismatch
    (error_options[:filter] ||= {}).merge!(expected_data_type: data_type.to_s, nested_field: "conditions.value", code: :invalid_value)
  end

  def check_field_values(input_value, allowed_values, field_name, type)
    expected_values = check_label_exist(allowed_values[0]) ? fetch_label_of_choices(allowed_values) : fetch_name_of_choices(allowed_values)
    if(type == "text")
      unless expected_values.include?(input_value)
        errors[:filter] = :not_included
        (error_options[:filter] ||= {}).merge!(list: expected_values.join(", "), nested_field: "conditions.#{field_name}.#{input_value}", code: :invalid_value)
      end
    elsif (type == "multi_text")
      invalid_values = input_value - expected_values
      if invalid_values.present?
        errors[:filter] = :not_included
        (error_options[:filter] ||= {}).merge!(list: expected_values.join(", "), nested_field: "conditions.#{field_name}.#{input_value}", code: :invalid_value)
      end
    end
  end

  private

  def build_contact_field_hash
    @contact_fields["contact_fields"].map { |field| { field[:name] => field.except(:name) } }.reduce(:merge)
  end

  def build_company_field_hash
    @company_fields["company_fields"].map { |field| { field[:name] => field.except(:name) } }.reduce(:merge)
  end

  def check_filter_errors?
    errors[:filter].blank?
  end

  def fetch_name_of_choices(choices)
    choices.map { |choice| choice[:name] }
  end

  def fetch_label_of_choices(choices)
    choices.map { |choice| choice[:label] }
  end

  def check_label_exist(choice)
    choice[:label].present? ? true : false
  end

  def check_valid_boolean(value)
    (true?(value) || false?(value)) ? true : false
  end

  def numeric?(value)
    begin
      !Float(value).nil?
    rescue Exception => e
      false
    end
  end

  def true?(value)
    value.to_s == "true" || value.to_s == CHECKED
  end

  def false?(value)
    value.to_s == "false" || value.to_s == NOT_CHECKED
  end

  #date validation methods set option = false for date-time validation
  def invalid_date?(value, option = true)
    !parse_time(value, option)
  end

  def parse_time(value, option)
    DateTime.iso8601(value) && DateTime.parse(value) && iso8601_format(value, option)
    parse_sec_hour_and_zone(get_time_and_zone(value)) if time_info?(value, option) # avoid extra call if only date is present
    return true
  rescue => e
    Rails.logger.error("Parse Time Error Value: #{value} Exception: #{e.class} Exception Message: #{e.message}")
    return false
  end

  def iso8601_format(value, option)
    raise(ArgumentError, FORMAT_EXCEPTION_MSG) unless value =~ date_time_regex_for_value(option)
    true
  end

  def time_info?(value, option)
    !option && value.include?(ISO_DATE_DELIMITER)
  end

  def date_time_regex_for_value(option)
    option ? DATE_REGEX : DATE_TIME_REGEX
  end

  def get_time_and_zone(value)
    value.split(ISO_DATE_DELIMITER).last
  end

  def parse_sec_hour_and_zone(tz_value) # time_and_zone_value
    raise(ArgumentError, TIME_EXCEPTION_MSG) unless valid_time(tz_value) && valid_zone(tz_value)
  end

  def valid_time(tz_value)
    # only seconds: 60 and hour: 24 needs to be handled here, as all other invalid values would be caught in parse.
    valid_sec(tz_value) && valid_hour(tz_value)
  end

  def valid_sec(tz_value)
    tz_value.exclude?(UNHANDLED_SECOND_VALUE) # :60
  end

  def valid_hour(tz_value)
    tz_value.split(ISO_TIME_DELIMITER).first != UNHANDLED_HOUR_VALUE # if : is absent and T is present parse would have failed.
  end

  def valid_zone(tz_value)
    if tz_value.include?(ZONE_PLUS_PREFIX)
      zone = tz_value.split(ZONE_PLUS_PREFIX).last
    elsif tz_value.include?(ZONE_MINUS_PREFIX)
      zone = tz_value.split(ZONE_MINUS_PREFIX).last
    end
    zone.nil? || validate_zone(zone)
  end

  def validate_zone(zone)
    # zone has to be in format +hhmm or -hhmm | +hh:mm or -hh:mm | +hh or -hh
    hh = zone[0..1]
    mm = zone[-1..-2] if zone.size != 2
    hh.to_i.between?(0, 23) && mm.to_i.between?(0, 59)
  end
end