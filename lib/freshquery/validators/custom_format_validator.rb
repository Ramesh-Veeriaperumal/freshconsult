module Freshquery
  module Validators
    class CustomFormatValidator < BaseValidator
      private

        def message
          "It should be in the 'valid #{attribute}' format"
        end

        def invalid?
          regexp = call_block(options[:with])
          value !~ regexp
        end
    end
  end
end