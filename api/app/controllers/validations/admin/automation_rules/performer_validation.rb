module Admin::AutomationRules
  class PerformerValidation < ApiValidation
    include Admin::AutomationValidationHelper

    attr_accessor :type, :members
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position

    validates :type, presence: true, data_type: { rules: Integer }
    validate :validate_type
    validate :validate_members

    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    def initialize(request_params, item, allow_string_param = false)
      @type_name = :performer
      self.skip_hash_params_set = true
      super(request_params, item, allow_string_param)
    end

    private

      def validate_type
        not_included_error(:type, (1..4).to_a) unless  type >= 1 && type <= 4
      end

      def validate_members
        unexpected_parameter(:members, :unexpected_members_for_performer) if type != 1 && members.present?
        if type == 1 && members.is_a?(Array) && !(members.all? { |member| member.is_a?(Integer) })
          invalid_data_type(:members, :Number, :invalid)
        end
      end
  end
end
