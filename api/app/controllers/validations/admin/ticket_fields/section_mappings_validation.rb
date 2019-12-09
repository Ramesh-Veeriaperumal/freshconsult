module Admin
  module TicketFields
    class SectionMappingsValidation < ApiValidation
      include Admin::TicketFieldHelper
      
      attr_accessor :ticket_field, :section_mappings

      validate :validate_section_features
      validate :validate_section_mappings

      def initialize(params, item, options = {})
        self.ticket_field = item
        super(params, item, options)
      end

      private

        def validate_section_features
          missing_feature_error(:multi_dynamic_sections) unless current_account.multi_dynamic_sections_enabled?
        end

        def validate_section_mappings
          if section_mappings.is_a?(Array)
            section_mappings.each do |mapping|
              validate_data_type(mapping)
              validate_section_mapping(mapping)
            end
            validate_redundant_sections
          else
            invalid_data_type(:section_mappings, Array, section_mappings.class)
          end
        end

        def validate_redundant_sections
          sections = section_mappings.map {|mapping| mapping[:section_id]}
          invalid_section_mapping_error(:redundant_section_mapping, :section_id, :redundant_parameter) unless sections.uniq.count == sections.count
        end

        def validate_section_mapping(section_mapping)
          unless section_mapping.is_a?(Hash)
            invalid_data_type(:section_mapping_data_type, Hash, section_mapping.class)
            return
          end

          missing_params = ALLOWED_HASH_SECTION_MAPPINGS - section_mapping.keys
          missing_param_error(:section_mapping_param_missing, missing_params.join(', ')) if missing_params.present?
          return
        end

        def validate_data_type(section_mapping)
          section_mapping.each do |key, item|
            unless item.is_a?(Integer)
              invalid_data_type(:"section_mapping[#{key}]", Integer, item.class)
              return
            end
            invalid_data_type(:"section_mapping[#{key}]", 'greater than 0', item.inspect) unless item > 0
          end
        end
    end
  end
end