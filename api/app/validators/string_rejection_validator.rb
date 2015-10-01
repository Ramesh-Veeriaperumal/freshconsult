class StringRejectionValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    excluded_chars = options[:excluded_chars] || []
    case value
    when Array
      joined_array = value.join
      reject_special_chars(record, attribute, joined_array, excluded_chars)
    when String
      reject_special_chars(record, attribute, value, excluded_chars)
    else
    end
  end

  private

    def reject_special_chars(record, attribute, value, excluded_chars)
      if excluded_chars.any? { |x| value.include?(x)}
        record.errors.add(attribute, 'special_chars_present')
        (record.error_options ||= {}).merge!(attribute => {chars: excluded_chars.join('\',\'')})
      end
    end

end
