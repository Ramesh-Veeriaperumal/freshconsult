class FileSizeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    new_size = value.map(&:size).inject(:+)
    base_size = options[:base_size].respond_to?(:call) ? options[:base_size].call(record) : options[:base_size]
    size = new_size + base_size
    unless options[:min].to_i <= size && options[:max] >= size
      record.errors[attribute] = 'invalid_size'
    end
  end
end
