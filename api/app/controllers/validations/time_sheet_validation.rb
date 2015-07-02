class TimeSheetValidation < ApiValidation
  attr_accessor :billable, :executed_at, :time_spent, :ticket_id, :user_id, :note, :ticket, :timer_running, :start_time

  # do not change validation order
  validates :user_id, numericality: true, allow_nil: true
  validates :ticket_id, numericality: true
  # if ticket_id is not a number, to avoid query, below if condition is used.
  validates :ticket, presence: true, if: -> { errors[:ticket_id].blank? } 
  validates :executed_at, :start_time, date_time: { allow_nil: true }
  validates :billable, :timer_running, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates :time_spent, format: { with: /^(?:\d|[01]\d|2[0-3]):[0-5]\d$/, message: 'is not a valid time_spent', allow_nil: true }
  # start_time param has no meaning when timer is off 
  validates :start_time, inclusion: {in: [nil], 
          message: 'Should be blank if timer_running is false'}, if: -> { !timer_running }
  # start_time should be lesser than current_time to avoid negative time_spent values.
  validate :start_time_value, if: -> { start_time && errors[:start_time].blank?}

  def initialize(request_params, item, account, timer_running)
    super(request_params, item)
    @timer_running = timer_running
    @start_time = request_params['start_time']
    @ticket = account.tickets.find_by_param(request_params['ticket_id'], account)
  end

  private

    def start_time_value
      errors.add(:start_time, "Has to be greater than current time") if start_time.to_time.utc < Time.now.utc
    end 
end
