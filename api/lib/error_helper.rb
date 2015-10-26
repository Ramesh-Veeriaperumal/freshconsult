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
      errors.map(&:http_code).group_by { |i| i }.max { |x, y| x[1].length <=> y[1].length }[0]
    end

    def bad_request_error(att, val, meta)
      BadRequestError.new(att, val, meta)
    end

    # couldn't use dynamic forms/I18n for AR attributes translation as it may have an effect on web too.
    def rename_error_fields(fields = {}, item)
      if item.errors
        fields_to_be_renamed = fields.slice(*item.errors.to_h.keys)
        fields_to_be_renamed.each_pair do |model_field, api_field|
          item.errors.messages[api_field] = item.errors.messages.delete(model_field)
        end
      end
    end

    def rename_keys(mappings, fields_hash)
      return if fields_hash.blank?
      fields_hash.keys.each { |k| fields_hash[mappings[k]] = fields_hash.delete(k) if mappings[k] }
    end
  end
end
