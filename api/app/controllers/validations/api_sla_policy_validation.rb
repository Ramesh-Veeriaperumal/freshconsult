class ApiSlaPolicyValidation < ApiValidation
  attr_accessor :applicable_to, :company_ids, :name, :description, :active, :product_ids, :group_ids, :ticket_types, :sources,
                :sla_target, :priority_1, :priority_2, :priority_3, :priority_4,
                :escalation, :response, :resolution, :level_1, :level_2, :level_3, :level_4

  
  validates :name, data_type: { rules: String, allow_nil: false, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING} }
  validates :description, data_type: { rules: String, allow_nil: true }
  validates :active, data_type: { rules: 'Boolean'}

  validates :sla_target, data_type: { rules: Hash }
  validates :priority_1, data_type: { rules: Hash, required: true }, allow_nil: false, if: -> { sla_target.present? }
  validates :priority_2, data_type: { rules: Hash, required: true }, allow_nil: false, if: -> { sla_target.present? }
  validates :priority_3, data_type: { rules: Hash, required: true }, allow_nil: false, if: -> { sla_target.present? }
  validates :priority_4, data_type: { rules: Hash, required: true }, allow_nil: false, if: -> { sla_target.present? }

  validate :validate_sla_target, if: -> { sla_target.present? }

  validates :applicable_to, data_type: { rules: Hash }, allow_nil: false
  validates :company_ids, data_type: { rules: Array },
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { applicable_to.present? }                   
  validates :group_ids, data_type: { rules: Array },
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { applicable_to.present? }                   
  validates :product_ids, data_type: { rules: Array},
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { applicable_to.present? }                   
  validates :sources, data_type: {rules: Array },
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { applicable_to.present? }
  validates :ticket_types, data_type: { rules: Array },
                          array: { data_type: { rules: String, allow_nil: false }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }, if: -> { applicable_to.present? }

  validates :escalation, data_type: { rules: Hash }
  validates :response, data_type: { rules: Hash }, allow_nil: true, if: -> { escalation.present? }
  validate :escalation_response, if: -> { escalation.present? && escalation[:response].present? }
  validates :resolution, data_type: { rules: Hash }, allow_nil: true, if: -> { escalation.present? }
  validates :level_1, data_type: { rules: Hash}, allow_nil: false, if: -> { escalation.present? && escalation[:resolution].present? }
  validates :level_2, data_type: { rules: Hash}, allow_nil: false, if: -> { escalation.present? && escalation[:resolution].present? }
  validates :level_3, data_type: { rules: Hash}, allow_nil: false, if: -> { escalation.present? && escalation[:resolution].present? }
  validates :level_4, data_type: { rules: Hash}, allow_nil: false, if: -> { escalation.present? && escalation[:resolution].present? }
  validate :escalation_resolution_level, if: -> { escalation.present? && escalation[:resolution].present? }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, false)
  end

  def validate_sla_target
    self.sla_target.each do |level|
      sla_validator = ApiSlaDetailsValidation.new(level.second, nil)
      marge_error(sla_validator, "sla_target[#{level.first}]") if sla_validator.invalid?
    end
  end

  def escalation_response
    sla_validator = ApiSlaEscalationValidation.new(escalation["response"], nil)
    marge_error(sla_validator, "response") if sla_validator.invalid?
  end

  def escalation_resolution_level
    self.escalation[:resolution].each do |level|
      sla_validator = ApiSlaEscalationValidation.new(level.second, nil)
      marge_error(sla_validator, "resolution[#{level.first}]") if sla_validator.invalid?
    end
  end

  def marge_error(sla_validator,key)
    sla_validator.errors.messages.each do |err,val|
      if val.present?
        errors[:"#{key}[#{err}]"] << val.first
        error_options[:"#{key}[#{err}]"] = sla_validator.error_options[err]
      end
    end
  end

end