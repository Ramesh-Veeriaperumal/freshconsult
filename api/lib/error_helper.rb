class ErrorHelper
  class << self
    def format_error(errors, meta = {})
      meta.symbolize_keys!
      formatted_errors = []
      errors.to_h.each do |att, val|
        formatted_errors << bad_request_error(att.to_sym, val.to_sym, meta)
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
        fields_to_be_renamed = fields.select { |f| item.errors[f].present? } # ActiveModel::Errors object can respond to symbol and string, when accessed through [].
        fields_to_be_renamed.each_pair do |model_field, api_field|
          item.errors.messages[api_field.to_sym] = item.errors.delete model_field.to_sym
          # Even if we avoid api_field.to_sym, ActiveModel::Errors [] method is going to create that symbol. http://api.rubyonrails.org/v3.2.18/classes/ActiveModel/Errors.html#method-i-5B-5D
          # ActiveModel::Errors is not a hash_with_indifferent_access, delete expects symbols.
        end
      end
    end

    def rename_keys(mappings, fields_hash)
      return if fields_hash.blank?
      fields_hash.keys.each { |k| fields_hash[sym_key_lookup(mappings, k).to_sym] = fields_hash.delete(k) if sym_key_lookup(mappings, k) }
      # fields_hash will have both symbols and strings
    end

    def sym_key_lookup(hash, key)
      hash[key] || hash[key.to_s]
    end

    def rename_error_message(fields, item)
      if item.errors
        field_msg_to_be_renamed = fields.select { |f| item.errors[f].present? }
        field_msg_to_be_renamed.each_pair do |field, messages|
          api_messages = []
          messages.each_pair do |model_msg, api_msg|
            if item.errors[field].include?(model_msg)
              item.errors[field].delete(model_msg)
              api_messages.push(api_msg.to_sym)
            end
          end
          item.errors[field].concat(api_messages)
        end
      end
    end

  end
end
