class ApiSlaPolicyValidation < ApiValidation
  attr_accessor :applicable_to, :company_ids, :name, :description, :active, :is_default, :product_ids, :group_ids, :ticket_types, :sources, :contact_segments, :company_segments,
                :sla_target, :priority_1, :priority_2, :priority_3, :priority_4,
                :escalation, :reminder_response, :reminder_next_response, :reminder_resolution, :response, :next_response, :resolution, :level_1, :level_2, :level_3, :level_4,
                :position

  CHECK_PARAMS_SET_FIELDS = %w(applicable_to escalation).freeze

  validates :name,:applicable_to,:sla_target, required: true, on: :create
  validates :name, data_type: { rules: String, allow_nil: false},custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

  validates :description, data_type: { rules: String, allow_nil: true }
  validates :active, data_type: { rules: 'Boolean'}

  validates :position, data_type: { rules: Integer }, on: :update

  validates :sla_target, data_type: { rules: Hash }
  validates :priority_1, data_type: { rules: Hash, required: true }, allow_nil: false, if: -> { sla_target.present? }
  validates :priority_2, data_type: { rules: Hash, required: true }, allow_nil: false, if: -> { sla_target.present? }
  validates :priority_3, data_type: { rules: Hash, required: true }, allow_nil: false, if: -> { sla_target.present? }
  validates :priority_4, data_type: { rules: Hash, required: true }, allow_nil: false, if: -> { sla_target.present? }

  validate :validate_sla_target, if: -> { sla_target.present? }

  validates :applicable_to, data_type: { rules: Hash }, allow_nil: false
  validates :company_ids, data_type: { rules: Array },
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { applicable_to.present? && !private_api? }                   
  validates :company_ids, data_type: { rules: Array },
                          array: { data_type: { rules: String, allow_nil: false } }, if: -> { applicable_to.present? && private_api? }
  validates :group_ids, data_type: { rules: Array },
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { applicable_to.present? }                   
  validates :product_ids, data_type: { rules: Array},
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { applicable_to.present? }                   
  validates :sources, data_type: {rules: Array },
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { applicable_to.present? }
  validates :ticket_types, data_type: { rules: Array },
                          array: { data_type: { rules: String, allow_nil: false }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }, if: -> { applicable_to.present? }
  validates :contact_segments, :company_segments, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: { attribute: 'contact_segments', feature: :segments }
  }, unless: -> { Account.current.segments_enabled? }
  validates :contact_segments, data_type: { rules: Array },
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { errors[:contact_segments].blank? && applicable_to.present? }
  validates :company_segments, data_type: { rules: Array },
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { errors[:company_segments].blank? && applicable_to.present? }

  validates :escalation, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: { attribute: 'escalation', feature: :sla_management } 
  }, unless: -> { Account.current.sla_management_enabled? }
  validates :escalation, data_type: { rules: Hash }

  validates :reminder_response, data_type: { rules: Hash }, allow_nil: true, if: -> { escalation.present? }
  validate :escalation_reminder_response, if: -> { escalation.present? && escalation[:reminder_response].present? }
  validates :response, data_type: { rules: Hash }, allow_nil: true, if: -> { escalation.present? }
  validate :escalation_response, if: -> { escalation.present? && escalation[:response].present? }

  validate :next_response_sla_feature_presence, if: -> { escalation.present? }
  validates :reminder_next_response, data_type: { rules: Hash }, allow_nil: true, if: -> { errors[:reminder_next_response].blank? && :escalation.present? }
  validate :escalation_reminder_next_response, if: -> { errors[:reminder_next_response].blank? && escalation.present? && escalation[:reminder_next_response].present? }
  validates :next_response, data_type: { rules: Hash }, allow_nil: true, if: -> { errors[:next_response].blank? && escalation.present? }
  validate :escalation_next_response, if: -> { errors[:next_response].blank? && escalation.present? && escalation[:next_response].present? }

  validates :reminder_resolution, data_type: { rules: Hash }, allow_nil: true, if: -> { escalation.present? }
  validate :escalation_reminder_resolution, if: -> { escalation.present? && escalation[:reminder_resolution].present? }
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
      sla_validator = private_api? ? Ember::SlaDetailsValidation.new(level.second, nil) : ApiSlaDetailsValidation.new(level.second, nil)
      merge_error(sla_validator, "sla_target[#{level.first}]") if sla_validator.invalid?
    end
  end

  SlaPolicyConstants::ESCALATION_TYPES_EXCEPT_RESOLUTION.each do |type|
    define_method "escalation_#{type}" do
      validate_escalation_hash(type, escalation[type])
    end
  end

  def escalation_resolution_level
    self.escalation[:resolution].each do |level|
      validate_escalation_hash("resolution[#{level.first}]", level.second)
    end
  end

  def validate_escalation_hash(key, hash)
    validation_hash = hash.dup.merge(escalation_type: key)
    sla_validator = ApiSlaEscalationValidation.new(hash, nil)
    merge_error(sla_validator, key) if sla_validator.invalid?
  end

  def merge_error(sla_validator, key)
    sla_validator.errors.messages.each do |err,val|
      if val.present?
        errors[:"#{key}[#{err}]"] << val.first
        error_options[:"#{key}[#{err}]"] = sla_validator.error_options[err]
      end
    end
  end

  def next_response_sla_feature_presence
    unless Account.current.next_response_sla_enabled?
      [:reminder_next_response, :next_response].each do |key|
        if escalation.key?(key)
          errors["escalation_#{key}".to_sym] << :require_feature_for_attribute
          error_options["escalation_#{key}".to_sym] = { code: :inaccessible_field, attribute: key.to_s, feature: :next_response_sla }
        end
      end
    end
  end
end