class TimeSheetValidation < ApiValidation
  attr_accessor :billable, :executed_at, :time_spent, :ticket_id, :user_id, :user, :note, :ticket, :item, :request_params, :timer_running, :start_time

  # do not change validation order
  validates :user_id, numericality: true, allow_nil: true
  validates :ticket_id, numericality: true, if: -> { item.nil? }
  # if ticket_id is not a number, to avoid query, below if condition is used.
  validates :ticket, presence: true, if: -> { errors[:ticket_id].blank? && item.nil? }
  # if user_id is not a number, to avoid query, below if condition is used.
  validates :user, presence: true,  if: -> { errors[:user_id].blank? && request_params.key?(:user_id) }
  validates :executed_at, :start_time, date_time: { allow_nil: true }
  validates :billable, :timer_running, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates :time_spent, format: { with: /^(?:\d|[01]\d|2[0-3]):[0-5]\d$/, message: 'is not a valid time_spent', allow_nil: true }
  # Should not set the timer running to the same value as before in update as it may introduce ambiguity regarding start_time
  validate :disallow_reset_timer_value, if: -> { item && request_params.include?(:timer_running) && errors[:timer_running].blank? }
  # start_time param has no meaning timer is already on in case of update.
  validates :start_time, inclusion: { in: [nil],
                                      message: 'Should be blank if timer_running was true already' },
                         if: -> { errors[:start_time].blank? && errors[:timer_running].blank? && item && item.timer_running }
  # start_time param has no meaning when timer is off.
  validates :start_time, inclusion: { in: [nil],
                                      message: 'Should be blank if timer_running is false' },
                         if: -> { errors[:start_time].blank? && errors[:timer_running].blank? && !timer_running }
  # start_time should be lesser than current_time to avoid negative time_spent values.
  validate :start_time_value, if: -> { start_time && errors[:start_time].blank? }
  # user_id can't be changed in update if timer is running for the user.
  validates :user_id, inclusion: { in: [nil], message: "Can't update user when timer is running" },
                      if: -> {  item && item.timer_running && request_params.key?(:user_id) && item.user_id != request_params[:user_id] }

  def initialize(request_params, item, account, timer_running)
    super(request_params, item)
    @request_params = request_params
    @item = item
    @start_time = request_params['start_time']
    @timer_running = timer_running
    @user = account.agents_from_cache.find { |x| x.user_id == user_id } if request_params.key?(:user_id)
    @ticket = account.tickets.find_by_param(request_params['ticket_id'], account) if item.nil?
  end

  private

    def disallow_reset_timer_value
      errors.add(:timer_running, "Can't set to the same value as before") if request_params[:timer_running].to_s.to_bool == item.timer_running.to_s.to_bool
    end

    def start_time_value
      errors.add(:start_time, 'Has to be lesser than current time') if start_time.to_time.utc > Time.zone.now.utc
    end
end
