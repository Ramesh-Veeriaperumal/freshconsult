class ApiSlaDetailsValidation < ApiValidation
  attr_accessor :sla_details_id, :priority, :respond_within, :resolve_within, :business_hours, :escalation_enabled

  validates :respond_within, required: true, custom_numericality: { only_integer: true } 
  validates :respond_within, numericality: { greater_than_or_equal_to: SlaPolicyConstants::VALID_SLA_TIME[:min_sla_time], less_than_or_equal_to: SlaPolicyConstants::VALID_SLA_TIME[:max_sla_time] }, if: -> { errors[:respond_within].blank? }

  validates :resolve_within, required: true, custom_numericality: { only_integer: true }
  validates :resolve_within, numericality: { greater_than_or_equal_to: SlaPolicyConstants::VALID_SLA_TIME[:min_sla_time], less_than_or_equal_to: SlaPolicyConstants::VALID_SLA_TIME[:max_sla_time] }, if: -> { errors[:resolve_within].blank? }
  
  validates :business_hours, required: true, data_type: { rules: 'Boolean'}
  
  validates :escalation_enabled, required: true, data_type: { rules: 'Boolean'}

  validate :valid_respond_within?, if: -> { errors[:respond_within].blank? }
  validate :valid_resolve_within?, if: -> { errors[:resolve_within].blank? }
  
  def initialize(request_params, item, allow_string_param = false)
    @request_params = request_params
    super(request_params, item, true)
  end

  def valid_respond_within?
    errors[:respond_within] << :Multiple_of_60 if @request_params[:respond_within]%60 != 0
  end

  def valid_resolve_within?
    errors[:resolve_within] << :Multiple_of_60 if @request_params[:resolve_within]%60 != 0
  end
  
end
