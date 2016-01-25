# Overriding default validator to add custom message to inclusion validation.

class CustomInclusionValidator < ActiveModel::Validations::InclusionValidator
  def validate_each(record, attribute, value)
    return if record.errors[attribute].present?

    # delimiter is an ActiveModel::Validations::InclusionValidator method.
    # It returns options[:in] || options[:within]
    inclusion_list = delimiter.respond_to?(:call) ? delimiter.call(record) : delimiter

    # Include string representation of values also in the list if ignore_string is true.
    # When URL params or multipart/form-data request params are validated, ignore_string will be true.
    inclusion_list = (inclusion_list | inclusion_list.map(&:to_s)) if !options[:ignore_string].nil? && record.send(options[:ignore_string])

    # In the case of dependant fields it is possible to have choices as empty array. Hence, the below check is included.
    record.errors[attribute] << :should_be_blank if value.present? && inclusion_list.empty?

    unless inclusion_list.include?(value) || inclusion_list.empty?

      # message should be different if the attribute is required but not defined.
      message = options[:message]
      message ||= required_attribute_not_defined?(record, attribute, value) ? :required_and_inclusion : :not_included
      record.errors[attribute] << message

      # In order to give the permissible list in the error message, below check is done.
      if record.methods.include?(:error_options) && !options[:exclude_list]
        (record.error_options ||= {}).merge!(attribute => { list: inclusion_list.map(&:to_s).uniq.join(',') })
      end
    end
  end

  def required_attribute_not_defined?(record, attribute, _value)
    options[:required] && !record.instance_variable_defined?("@#{attribute}")
  end
end
