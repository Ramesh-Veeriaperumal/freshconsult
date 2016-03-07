# Overriding default validator to add custom message to inclusion validation.

class CustomInclusionValidator < ApiValidator
  def message
    values[:list].empty? ? :should_be_blank : :not_included
  end

  def invalid?
    modified_inclusion_list.exclude?(value)
  end

  def modified_inclusion_list
    modified_inclusion_list = inclusion_list
    modified_inclusion_list |= modified_inclusion_list.map(&:to_s) if allow_string?
    modified_inclusion_list += [nil] if values[:list].empty?
    modified_inclusion_list
  end

  def inclusion_list
    values[:list] = call_block(delimiter)
  end

  def delimiter
    options[:in] || options[:within]
  end

  def error_options
    error_options = add_input_info? ? { prepend_msg: :input_received, given_data_type: String } : {}
    error_options.merge!(list: values[:list].map(&:to_s).uniq.join(',')) unless options[:exclude_list]
    error_options
  end

  def add_input_info?
    data_type_mismatch? && values[:array].nil?
  end

  def error_code
    if required_attribute_not_defined?
      :missing_field
    elsif values[:data_type_mismatch]
      :data_type_mismatch
    end
  end

  def data_type_mismatch?
    values[:data_type_mismatch] = options[:detect_type] && !values[:allow_string] && values[:list].any? { |x| x.to_s == value }
  end
end
