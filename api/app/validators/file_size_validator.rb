class FileSizeValidator < ApiValidator
  include ActionView::Helpers::NumberHelper

  private

    def message
      :invalid_size
    end

    def invalid?
      return unless value.respond_to?(:size)
      !(options[:min].to_i <= current_size && options[:max] >= current_size)
    end

    def custom_error_options
      { current_size: number_to_human_size(current_size), max_size: number_to_human_size(options[:max]) }
    end

    def allow_nil?(_validator_options)
      value.nil?
    end

    def current_size
      return internal_values[:size] if internal_values.key?(:size)
      base_size = call_block(options[:base_size])
      new_size = (value.is_a? Array) ? value.map(&:size).inject(:+) : value.size
      internal_values[:size] = new_size.to_i + base_size.to_i
    end
end
