class ErrorHelper
  class << self
    def format_error(errors, meta = nil)
      formatted_errors = []
      errors.to_h.each do |att, val|
        formatted_errors << bad_request_error(att, val.to_s, meta)
      end
      formatted_errors
    end

    def find_http_error_code(errors) # returns most frequent error in an array
      errors.collect(&:http_code).group_by { |i| i }.max { |x, y| x[1].length <=> y[1].length }[0]
    end

    def get_translation_params(meta)
      { meta: meta } # this is being set in set_custom_errors
    end

    def bad_request_error(att, val, meta)
      BadRequestError.new(att, val, get_translation_params(meta))
    end
  end
end
