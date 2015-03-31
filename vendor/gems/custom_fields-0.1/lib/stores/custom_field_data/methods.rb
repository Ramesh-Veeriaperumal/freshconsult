module Stores
  module CustomFieldData

    module Methods
      
      def ff_def                            # Remove this later
        read_attribute form_id
      end
      
      def ff_def= ff_def_id                 # Remove this later
        write_attribute form_id, ff_def_id
      end
      
      def get_ff_value ff_alias
        ff_field = to_ff_field ff_alias
        if ff_field
          send(ff_field)
        else
          raise ArgumentError, "CustomField alias: #{ff_alias} not found in flexifeld def mapping"
        end
      end
      
      def set_ff_value ff_alias, ff_value
        ff_field = to_ff_field ff_alias
        if ff_field
          ff_value = nil if ff_value.blank?
          send :"#{ff_field}=", ff_value
        else
          raise ArgumentError, "CustomField alias: #{ff_alias} not found in flexifeld def mapping"
        end
      end
      
      def assign_ff_values args_hash
        unless args_hash.is_a? Hash
          raise ArgumentError, "Method argument must be a hash"
        end
        args_hash.each do |ffalias, ffvalue|
          set_ff_value ffalias, ffvalue
        end
      end

      def retrieve_ff_values
        ff_aliases.inject({}) do  |ff_values, ff_alias| 
          ff_values[ff_alias] = (get_ff_value ff_alias)
          ff_values
        end || {}
      end

    end

  end
end