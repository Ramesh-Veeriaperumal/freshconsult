class ConditionsValidation < ApiValidation
  include Admin::ConditionValidationHelper
  include Admin::CustomFieldHelper
  include Admin::ConditionHelper
  include Admin::ConditionErrorHelper

  attr_accessor :conditions, :custom_fields, :default_fields, :all_fields, :custom_field_hash, :validator_type, :rule_type,
                :field_position, :type_name, :invalid_attributes
  validate :conditions_validation, :validate_condition_keys, if: -> { conditions.present? }
  validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

  def initialize(conditions, default_fields, custom_fields, all_fields, type = :automation, rule_type = 1)
    @type = type
    safe_send('conditions=', conditions)
    safe_send('custom_fields=', custom_fields)
    safe_send('default_fields=', default_fields)
    safe_send('all_fields=', all_fields)
    safe_send('rule_type=', rule_type)
    safe_send('validator_type=', :condition)
    (custom_fields[0] + default_fields).each do |name|
      self.class.safe_send(:attr_accessor, name)
    end
    super(initialize_params(conditions, default_fields, custom_fields, rule_type), nil, false)
  end

  private

    def conditions_validation
      self.type_name = 'conditions'
      attribute_type(all_fields)
    end

    def validate_condition_keys
      conditions.each_with_index do |condition, index|
        self.field_position = index + 1
        CONDITION_SET_PROPERTIES.each { |valid_param|
          missing_field_error("condition", valid_param) and return unless condition.keys.map(&:to_sym).include? valid_param }
      end
      self.field_position = nil
    end
end
