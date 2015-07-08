# Overriding defualt validator to add custom message to inclusion validation.

class IncludedValidator < ActiveModel::Validations::InclusionValidator
  def validate_each(record, attribute, value)
    exclusions = delimiter.respond_to?(:call) ? delimiter.call(record) : delimiter
    unless exclusions.send(inclusion_method(exclusions), value)
      record.errors.add(attribute, :inclusion, options.merge(value: value, message: 'not_included'))
      (record.error_options ||= {}).merge!(attribute => { list: exclusions.map(&:to_s).uniq.join(',') })
    end
  end
end
