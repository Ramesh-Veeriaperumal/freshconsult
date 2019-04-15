module Admin::AutomationRules::Conditions
  class CompanyValidation < ApiValidation
    include Admin::AutomationValidationHelper

    VALID_ATTRIBUTES = (Admin::AutomationConstants::CONDITION_COMPANY_FIELDS +
                        Admin::AutomationConstants::TAM_COMPANY_FIELDS).uniq

    attr_accessor(*VALID_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position

    validate :company_conditions_attribute_type
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    validates :segments, custom_absence:
        { message: :require_feature_for_attribute,
          code: :inaccessible_field,
          message_options: {
            attribute: 'segments',
            feature: :segments
          } }, unless: :segments_enabled?
    validates :health_score, custom_absence:
        { message: :require_feature_for_attribute,
          code: :inaccessible_field,
          message_options: {
            attribute: 'health_score',
            feature: :tam_default_fields
          } }, unless: :tam_default_fields_enabled?

    validates :account_tier, custom_absence:
        { message: :require_feature_for_attribute,
          code: :inaccessible_field,
          message_options: {
            attribute: 'account_tier',
            feature: :tam_default_fields
          } }, unless: :tam_default_fields_enabled?

    validates :industry, custom_absence:
        { message: :require_feature_for_attribute,
          code: :inaccessible_field,
          message_options: {
            attribute: 'industry',
            feature: :tam_default_fields
          } }, unless: :tam_default_fields_enabled?

    validates :renewal_date, custom_absence:
        { message: :require_feature_for_attribute,
          code: :inaccessible_field,
          message_options: {
            attribute: 'renewal_date',
            feature: :tam_default_fields
          } }, unless: :tam_default_fields_enabled?

    def initialize(request_params, _item, set, rule_type, _allow_string_param = false)
      @rule_type = rule_type
      @type_name = "conditions[:condition_set_#{set}][:company]"
      super(initialize_params(request_params, VALID_ATTRIBUTES), nil, false)
    end

    def company_conditions_attribute_type
      Admin::AutomationConstants::CONDITION_COMPANY_FIELDS_HASH.each do |condition|
        attribute_value = safe_send(condition[:name])
        next if attribute_value.blank?
        @field_position = 1
        attribute_value.each do |each_attribute|
          condition_validation(condition, each_attribute)
          @field_position += 1
        end
      end
    end

    def tam_default_fields_enabled?
      Account.current.tam_default_fields_enabled?
    end

    def segments_enabled?
      Account.current.segments_enabled?
    end
  end
end
