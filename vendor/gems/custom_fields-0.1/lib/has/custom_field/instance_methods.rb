module Has
  module CustomField
  
    module InstanceMethods

      # To keep flexifield & @custom_field in sync
      def custom_field
        @custom_field ||= retrieve_ff_values
      end

      def custom_field= custom_field_hash
        unless custom_field_hash.blank?
          @custom_field = nil # resetting to reflect the assignments properly
          assign_ff_values custom_field_hash
        end
      end

    end
  
  end
end