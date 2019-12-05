module UtilityHelper
  # overriding this method to work for array as value
  def deep_symbolize_keys(changes)
    symbolize = lambda do |value|
      case value
        when Hash
          deep_symbolize_keys(value)
        when Array
          value.map { |value| symbolize.call(value) }
        else
          value
      end
    end
    changes.each_with_object({}) do |(key, value), result|
      result[(begin
        key.to_sym
      rescue StandardError
        key
      end) || key] = symbolize.call(value)
    end
  end

  def extract_duplicate_values_in_array(values)
    dup_values = values.group_by { |e| e }.select { |_, v| v.size > 1 }
    dup_values.keys
  end

  def valid_type?(value, type)
    case value
      when type
        true
      when TrueClass, FalseClass
        type == 'bool'
      else
        false
    end
  end
end