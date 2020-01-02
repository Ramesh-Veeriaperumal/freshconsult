class Ember::SlaDetailsValidation < ApiValidation
  attr_accessor :sla_details_id, :priority, :first_response_time, :every_response_time, :resolution_due_time, :business_hours, :escalation_enabled

  CHECK_PARAMS_SET_FIELDS = %w[every_response_time].freeze

  validates :first_response_time, required: true, data_type: { rules: String }
  validates :resolution_due_time, required: true, data_type: { rules: String }
  validates :every_response_time, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: { attribute: 'every_response_time', feature: :next_response_sla }
  }, unless: -> { Account.current.next_response_sla_enabled? }
  validates :every_response_time, allow_blank: true, data_type: { rules: String }

  validate :valid_first_response_time?, if: -> { errors[:first_response_time].blank? }
  validate :valid_every_response_time?, if: -> { @request_params[:every_response_time].present? && errors[:every_response_time].blank? }
  validate :valid_resolution_due_time?, if: -> { errors[:resolution_due_time].blank? }

  validates :business_hours, required: true, data_type: { rules: 'Boolean' }
  validates :escalation_enabled, required: true, data_type: { rules: 'Boolean' }

  def initialize(request_params, item, allow_string_param = false)
    @request_params = request_params
    super(request_params, item, true)
  end

  Helpdesk::SlaDetail::SLA_TARGETS_COLUMN_MAPPINGS.keys.each do |new_column|
    define_method "valid_#{new_column}?" do
      valid_formatted_time?(new_column.to_sym, @request_params[new_column.to_sym]) if @request_params[new_column.to_sym].present?
    end
  end

  def valid_formatted_time?(sla_time, formatted_time)
    target_time = Helpdesk::SlaDetail.new.target_time_in_seconds(formatted_time)
    errors[sla_time] << :invalid_duration_format if target_time.nil?
    errors[sla_time] << :must_be_less_than_1_year if errors[sla_time].blank? && target_time > 1.year
    errors[sla_time] << :must_be_more_than_15_minutes if errors[sla_time].blank? && target_time < 15.minutes
  end
end
