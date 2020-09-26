class ApiFreshfone::CallHistoryFilterValidation < FilterValidation
  attr_accessor :call_type, :user_ids, :business_hour_call, :number, :requester_id, :group_id, :start_date, :end_date, :export_format, :company_id

  validates :call_type, data_type: { rules: String, allow_nil: true }
  validates :call_type, custom_inclusion: { in: ApiFreshfone::CallHistoryConstants::CALL_TYPE }
  validates :requester_id, :group_id, :company_id, custom_numericality: { only_integer: true, ignore_string: :allow_string_param, greater_than: 0 }
  validates :business_hour_call, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }
  validates :user_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }
  validates :start_date, :end_date, date_time: { allow_nil: true }
  validates :export_format, data_type: { rules: String, allow_nil: true }
  validates :export_format, custom_inclusion: { in: ApiFreshfone::CallHistoryConstants::EXPORT_FORMAT }

  validate :date_range, if: -> { @start_date || @end_date }
  validate :active_freshfone_number, if: -> { @number }

  def initialize(request_params)
    @start_date = request_params[:start_date]
    @end_date = request_params[:end_date]
    @number = request_params[:number]
    super(request_params, nil, true)
  end

  def date_range
    errors[:start_date] << :"Either both start_date and end_date or none are expected" unless @start_date.present? && @end_date.present?
    errors[:start_date] << :"date_range should be within 6 months" if max_date_range_exceeded?
    errors[:end_date] << :"end_date can't be less than start_date" if (@start_date.present? && @end_date.present?) && (@end_date < @start_date)
  end

  def max_date_range_exceeded?
    return unless @start_date.present? && @end_date.present?
    number_of_days = @end_date.to_date.mjd - @start_date.to_date.mjd
    number_of_days >= Freshfone::Call::EXPORT_RANGE_LIMIT_IN_MONTHS * 31
  end

  def active_freshfone_number
    errors[:number] << :"Number is either not found or not active" unless Account.current.freshfone_numbers.active_number(@number).present?
  end
end
