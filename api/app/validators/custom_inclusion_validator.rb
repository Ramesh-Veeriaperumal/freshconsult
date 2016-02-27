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
    error_options = { list: values[:list].map(&:to_s).uniq.join(',') } unless options[:exclude_list]
    code = required_attribute_not_defined? ? :missing_field : error_code
    error_options.merge!(code: code) if code
    error_options
  end

  def error_code
    :data_type_mismatch if options[:detect_type] && !values[:allow_string] && values[:list].any? { |x| x.to_s == value }
  end
end
