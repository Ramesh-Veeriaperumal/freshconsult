class FileSizeValidator < ActiveModel::EachValidator
  include ActionView::Helpers::NumberHelper

  def validate_each(record, attribute, value)
    return unless value.respond_to?(:size) && record.errors[attribute].blank?
    new_size = (value.is_a? Array) ? value.map(&:size).inject(:+) : value.size
    base_size = options[:base_size].respond_to?(:call) ? options[:base_size].call(record) : options[:base_size]
    size = new_size.to_i + base_size.to_i
    unless options[:min].to_i <= size && options[:max] >= size
      record.errors[attribute] = 'invalid_size'
      (record.error_options ||= {}).merge!(attribute => { max_size: number_to_human_size(options[:max]) })
    end
  end
end
