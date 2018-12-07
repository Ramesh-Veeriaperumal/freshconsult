module Admin
  class AutomationValidation < ApiValidation
    include Admin::AutomationConstants

    attr_accessor :rule_type

    validate :check_for_allowed_rule_type, only: [:index]

    def initialize(request_params, item = nil, allow_string_param = false)
      super(request_params, item, allow_string_param)
    end

    def check_for_allowed_rule_type
      rule_name = VAConfig::RULES_BY_ID[rule_type.to_i]
      unless VAConfig::ASSOCIATION_MAPPING.key?(rule_name)
        errors[:rule_type] <<  :rule_type_not_allowed
        error_options[:rule_type] = {rule_type: rule_type.to_i}
      end
    end

  end
end
