# Overriding defualt validator to add custom message to inclusion validation.

class CustomInclusionValidator < ActiveModel::Validations::InclusionValidator
  def validate_each(record, attribute, value)
    inclusion_list = delimiter.respond_to?(:call) ? delimiter.call(record) : delimiter
    unless inclusion_list.send(inclusion_method(inclusion_list), value)

      # message should be different if the attribute is required but not defined.
      message = options[:message]
      message ||= options[:required] && !attribute_defined?(record, attribute) ? 'required_and_inclusion' : 'not_included'
      record.errors.add(attribute, :inclusion, options.merge(value: value, message: message))
      if record.methods.include?(:error_options) && !options[:exclude_list]
        (record.error_options ||= {}).merge!(attribute => { list: inclusion_list.map(&:to_s).uniq.join(',') })
      end
    end
  end

  def attribute_defined?(record, attribute)
    record.instance_variable_defined?("@#{attribute}".to_sym)
  end
end
