class TimeSheetValidation < ApiValidation
  attr_accessor :billable, :executed_at, :time_spent, :ticket_id, :user_id, :user, :note, :ticket, :item, :request_params, :timer_running, :start_time

  # do not change validation order
  # ************************************** Common validations ****************************************************

  validates :billable, :timer_running, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates :executed_at, date_time: { allow_nil: true }
  validates :time_spent, format: { with: /^(\d+):(\d+)$/, message: 'is not a valid time_spent', allow_nil: true }

  # ************************************** Start time specific validations ***************************************

  # start_time param has no meaning timer is already on in case of update.
  validates :start_time, inclusion: { in: [nil], message: 'Should be blank if timer_running was true already' }, if: -> { item.timer_running }, on: :update
  # start_time param has no meaning when timer is off.
  validates :start_time, inclusion: { in: [nil], message: 'Should be blank if timer_running is false' }, 
                         unless: -> { errors[:start_time].any? || errors[:timer_running].any? || timer_running }
  validates :start_time, date_time: { allow_nil: true }, if: -> { errors[:start_time].blank? }
  # start_time should be lesser than current_time to avoid negative time_spent values.
  validate :start_time_value, if: -> { start_time && errors[:start_time].blank? }

  # ************************************** Timer running validations *********************************************

  # Should not set the timer running to the same value as before in update as it may introduce ambiguity regarding start_time
  validate :disallow_reset_timer_value, if: -> { @timer_running_set && errors[:timer_running].blank? }, on: :update

  # ************************************** Ticket specific validations ********************************************

  validates :ticket_id, numericality: true, on: :create
  # if ticket_id is not a number, to avoid query, below if condition is used.
  validates :ticket, presence: true, if: -> { errors[:ticket_id].blank? }, on: :create

  # ************************************** User specific validations **********************************************

  # user_id can't be changed in update if timer is running for the user.
  validates :user_id, inclusion: { in: [nil], message: "Can't update user when timer is running" },
                      if: -> { item.timer_running && @user_id_set && item.user_id != user_id }, on: :update
  validates :user_id, numericality: true, allow_nil: true, if: -> { errors[:user_id].blank? }
  # if user_id is not a number or not set in update, to avoid query, below if condition is used.
  validates :user, presence: true,  if: -> { errors[:user_id].blank? && @user_id_set }

  def initialize(request_params, item, account, timer_running)
    super(request_params, item)
    check_params_set(request_params, item)
    @request_params = request_params
    @item = item
    @time_spent = request_params['time_spent']
    @start_time = request_params['start_time']
    @timer_running = timer_running
    @user = account.agents_from_cache.find { |x| x.user_id == user_id } if @user_id_set
    @ticket = account.tickets.find_by_param(request_params['ticket_id'], account) if @ticket_id_set
  end

  private

    def disallow_reset_timer_value
      errors.add(:timer_running, "Can't set to the same value as before") if request_params[:timer_running].to_s.to_bool == item.timer_running.to_s.to_bool
    end

    def start_time_value
      errors.add(:start_time, 'Has to be lesser than current time') if start_time.to_time.utc > Time.now.utc
    end
end
