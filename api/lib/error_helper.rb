class ErrorHelper
  LIST_FIELDS = {
    forum_visibility: Forum::VISIBILITY_KEYS_BY_TOKEN.values.join(','),
    forum_type: Forum::TYPE_KEYS_BY_TOKEN.values.join(','),
    sticky: ApiConstants::BOOLEAN_VALUES.map(&:to_s).uniq.join(','),
    locked: ApiConstants::BOOLEAN_VALUES.map(&:to_s).uniq.join(','),
    answer: ApiConstants::BOOLEAN_VALUES.map(&:to_s).uniq.join(',')
  }

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
      { list: LIST_FIELDS[attribute], # this gives the accepted list when param fails inclusion validation.
        meta: meta } # this is being set in set_custom_errors
    end
  end
end
