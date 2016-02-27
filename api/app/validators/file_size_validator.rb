class FileSizeValidator < ApiValidator
  include ActionView::Helpers::NumberHelper

  def message
    :invalid_size
  end

  def invalid?
    return unless value.respond_to?(:size)
    new_size = (value.is_a? Array) ? value.map(&:size).inject(:+) : value.size
    base_size = call_block(options[:base_size])
    values[:size] = new_size.to_i + base_size.to_i
    !(options[:min].to_i <= values[:size] && options[:max] >= values[:size])
  end

  def error_options
    { current_size: number_to_human_size(values[:size]), max_size: number_to_human_size(options[:max]) }
  end

  def allow_nil?(_validator_options)
    value.nil?
  end
end
