class ApiSlaEscalationValidation < ApiValidation
  attr_accessor :escalation_type, :agent_ids, :escalation_time
  
  validates :escalation_time, required: true, custom_numericality: { only_integer: true }
  validate :escalation_time, custom_numericality: { greater_than_or_equal_to: 0 }, unless: :reminder?
  validate :escalation_time, custom_numericality: { lesser_than_or_equal_to: 0 }, if: :reminder?
  
  validates :agent_ids, required: true, data_type: { rules: Array },
                          array: { custom_numericality: { only_integer: true, greater_than_or_equal_to: SlaPolicyConstants::ASSIGNED_AGENT } },allow_nil: false                 
  
  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, true)
  end

  def reminder?
    escalation_type.present? && escalation_type.starts_with?('reminder_')
  end
end
