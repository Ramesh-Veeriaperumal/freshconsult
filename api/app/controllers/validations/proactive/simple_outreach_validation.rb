module Proactive
  class SimpleOutreachValidation < ApiValidation
    include SimpleOutreachConstants

    attr_accessor :selection

    validate :check_type, on: :create
    validates :selection, data_type: { rules: Hash, required: true}, 
                            hash: { validatable_fields_hash: proc { |x| x.validatable_selection_hash } 
                          }, if: -> { errors[:selection].blank? }, on: :create

    def validatable_selection_hash
      case selection[:type]
      when SELECTION_IMPORT
        {
          type: {
            data_type: { rules: String, required: true },
            custom_inclusion: { in: [SELECTION_IMPORT] }
          },
          contact_import: { data_type: { rules: Hash, required: true }, required: true }
        }
      end
    end

    private

      def check_type
        if selection[:type].blank?
          errors[:selection] = :datatype_mismatch
          (error_options[:selection] ||= {}).merge!(expected_data_type: String, nested_field: :type, code: :missing_field)
        elsif !SELECTION_TYPES.include?(selection[:type])
          errors[:selection] = :not_included
          (error_options[:selection] ||= {}).merge!(list: SELECTION_TYPES.join(", "), nested_field: :type, code: :invalid_value)
        end
      end
  end
end