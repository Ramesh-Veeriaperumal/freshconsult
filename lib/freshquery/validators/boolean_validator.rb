module Freshquery
  module Validators
    class BooleanValidator < BaseValidator
      # Introduced this as the error message should show layman terms.
      # DATA_TYPE_MAPPING = { Hash => 'key/value pair', ActionDispatch::Http::UploadedFile => 'valid file format', NilClass => NULL_TYPE, TrueClass => 'Boolean', FalseClass => 'Boolean' }

      private

        def invalid?
          !valid_type?
        end

        def message
          "It should be a/an Boolean"
        end

        def error_code
          :datatype_mismatch
        end

        def valid_type?
          return internal_values[:valid_type] if internal_values.key?(:valid_type)
          internal_values[:valid_type] = case value.downcase
          when 'true', 'false'
            true
          else
            false
          end
        end
    end
  end
end