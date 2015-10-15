module Stores
  module CustomFieldData

    module Methods
      
      def ff_def                            # Remove this later
        read_attribute form_id
      end
      
      def ff_def= ff_def_id                 # Remove this later
        write_attribute form_id, ff_def_id
      end
      
      def get_ff_value column_name, field_type
        process_while_reading(column_name, field_type)
      end
      
      def set_ff_value ff_alias, ff_value
        ff_field = to_ff_field ff_alias
        if ff_field
          ff_value = nil if ff_value.blank?
          write_attribute(ff_field, ff_value)
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
        custom_fields_cache.inject({}) do  |ff_values, custom_field| 
          ff_values[custom_field.name] = get_ff_value(custom_field.column_name, custom_field.field_type)
          ff_values
        end || {}
      end

      private

        def process_while_reading column_name, field_type
          value = read_attribute(column_name)
          case field_type
          when :custom_date
            value.utc if value.present?
          else
            value
          end
        end

    end

  end
end