module Inherits
  module CustomField
    module Constants

      include CustomFields::Constants

      def self.included base # will create FIELD_PROPS based on DEFAULT_FIELD_PROPS & CUSTOM_FIELDS_SUPPORTED
        if base.const_defined?(:DB_COLUMNS) && base.const_defined?(:"CUSTOM_FIELDS_SUPPORTED") && base.const_defined?(:"DEFAULT_FIELD_PROPS")
          custom_field_class = {}
          base::CUSTOM_FIELDS_SUPPORTED.each do |field_type|
            custom_field_class[field_type] = self::CUSTOM_FIELD_PROPS[field_type]
          end

          base.const_set(:CUSTOM_FIELD_PROPS, custom_field_class)
          base.const_set(:FIELD_PROPS, base::DEFAULT_FIELD_PROPS.merge(custom_field_class))

          base::DB_COLUMNS.each do |type, column_details|
            base::DB_COLUMNS[type][:columns] = (1..column_details[:column_limits]).collect{ |n| "#{column_details[:column_name]}#{"%02d" % n}"}
          end

          field_type_number_and_name = base::FIELD_PROPS.map do |field_name, field_details| [field_details[:type], field_name] end
          base.const_set(:FIELD_TYPE_NUMBER_TO_NAME, Hash[*field_type_number_and_name.flatten])
          
          temp_pools = base::CUSTOM_FIELD_PROPS.group_by{ |field_name, field_details| field_details[:db_column_type] }
          field_pools = temp_pools.inject({}) do |field_pools, (db_column_type, field_details)|
            field_pools[db_column_type] = field_details.map(&:second).map{|details| details[:type]}
            field_pools
          end
          base.const_set(:CUSTOM_FIELD_POOLS, field_pools)
        end
      end

    end
  end
end
