class FileSizeValidator < ApiValidator
  include ActionView::Helpers::NumberHelper

  def message
    :invalid_size
  end

  def invalid?
    return unless value.respond_to?(:size)
    new_size = (value.is_a? Array) ? value.map(&:size).inject(:+) : value.size
    base_size = call_block(options[:base_size])
    size = new_size.to_i + base_size.to_i
    !(options[:min].to_i <= size && options[:max] >= size)
  end

  def error_options
    { max_size: number_to_human_size(options[:max]) }
  end
end
