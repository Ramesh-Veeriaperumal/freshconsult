class ErrorHelper
  class << self
    def format_error(errors, meta = nil)
      formatted_errors = []
      errors.each do |attribute, value|
        formatted_errors << BadRequestError.new(attribute, value, get_translation_params(attribute, meta))
      end
      formatted_errors
    end

    def find_http_error_code(errors) # returns most frequent error in an array
      errors.collect(&:http_code).group_by { |i| i }.max { |x, y| x[1].length <=> y[1].length }[0]
    end

    def get_translation_params(attribute, meta)
      { list: ApiConstants::LIST_FIELDS[attribute.to_sym], # this gives the accepted list when param fails inclusion validation.
        meta: meta } # this is being set in set_custom_errors
    end
  end
end
