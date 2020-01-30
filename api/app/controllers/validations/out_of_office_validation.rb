class OutOfOfficeValidation < ApiValidation
  include OutOfOfficeConstants
  attr_accessor(*REQUEST_PERMITTED_PARAMS)

  validates :start_time, date_time: { required: true }
  validates :end_time, date_time: { required: true }
  validate :start_end_times, if: -> { start_time.present? && end_time.present? }

  def initialize(request_params)
    REQUEST_PERMITTED_PARAMS.each { |param| safe_send("#{param}=", request_params[param]) }
    super(request_params)
  end

  private

    def start_end_times
      errors[:start_time] = :start_time_less_than_end_time if start_time.to_time.utc >= end_time.to_time.utc
    end
end
