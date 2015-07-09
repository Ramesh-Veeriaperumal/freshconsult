# Overriding defualt validator to add custom message to inclusion validation.

class CustomInclusionValidator < ActiveModel::Validations::InclusionValidator
  def validate_each(record, attribute, value)
    inclusion_list = delimiter.respond_to?(:call) ? delimiter.call(record) : delimiter
    unless inclusion_list.send(inclusion_method(inclusion_list), value)
      record.errors.add(attribute, :inclusion, options.merge(value: value, message: 'not_included'))
      (record.error_options ||= {}).merge!(attribute => { list: inclusion_list.map(&:to_s).uniq.join(',') })
    end
  end
end
