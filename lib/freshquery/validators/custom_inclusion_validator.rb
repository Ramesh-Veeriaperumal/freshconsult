module Freshquery
  module Validators
    class CustomInclusionValidator < BaseValidator
      private

        def message
          if inclusion_list.empty?
            "It should not be set, as input is not expected"
          else
            "It should be one of these values: '#{inclusion_list.map(&:to_s).uniq.join(',')}'"
          end
        end

        def invalid?
          modified_inclusion_list.exclude?(value)
        end

        def modified_inclusion_list
          modified_inclusion_list = inclusion_list
          modified_inclusion_list |= modified_inclusion_list.map(&:to_s)
          modified_inclusion_list += [nil] if inclusion_list.empty?
          modified_inclusion_list
        end

        def inclusion_list
          return internal_values[:list] if internal_values.key?(:list)
          internal_values[:list] = call_block(options[:in])
        end
    end
  end
end