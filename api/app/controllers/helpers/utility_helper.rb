module UtilityHelper
  # overriding this method to work for array as value
  def deep_symbolize_keys(changes)
    symbolize = lambda do |value|
      case value
      when Hash
        deep_symbolize_keys(value)
      when Array
        value.map { |each_value| symbolize.call(each_value) }
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

  def match_type?(value, type)
    case value
    when type
      true
    when TrueClass, FalseClass
      type == 'bool'
    else
      false
    end
  end

  def match_children?(value, value_type, key_type = Symbol)
    case value
    when Array
      value.none? { |data| !match_type?(data, value_type) }
    when Hash
      value.none? { |key, val| !match_type?(key, key_type) || !match_type?(val, value_type) }
    else
      false
    end
  end
end
