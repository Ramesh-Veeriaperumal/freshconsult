class TimeSheetValidation < ApiValidation
  attr_accessor :billable, :executed_at, :time_spent, :ticket_id, :agent_id, :user, :note, :ticket, :item, :request_params, :timer_running, :start_time

  # do not change validation order
  # Common validations
  validates :billable, :timer_running, custom_inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates :executed_at, date_time: { allow_nil: true }
  validates :time_spent, format: { with: /^(\d+):(\d+)$/, message: 'invalid_time_spent', allow_nil: true }

  # Start time specific validations*
  # start_time param has no meaning timer is already on in case of update.
  validates :start_time, inclusion: { in: [nil], message: 'timer_running_true' }, if: -> { item.timer_running }, on: :update

  # start_time param has no meaning when timer is off.
  validates :start_time, inclusion: { in: [nil], message: 'timer_running_false' },
                         unless: -> { errors[:start_time].any? || errors[:timer_running].any? || timer_running }
  validates :start_time, date_time: { allow_nil: true }, if: -> { errors[:start_time].blank? }

  # start_time should be lesser than current_time to avoid negative time_spent values.
  validate :start_time_value, if: -> { start_time && errors[:start_time].blank? }

  # Timer running validations
  # Should not set the timer running to the same value as before in update as it may introduce ambiguity regarding start_time
  validate :disallow_reset_timer_value, if: -> { @timer_running_set && errors[:timer_running].blank? }, on: :update

  # Ticket specific validations
  validates :ticket_id, required: { allow_nil: false, message: 'required_and_numericality' }, on: :create
  validates :ticket_id, numericality: true, allow_nil: true,  on: :create

  # if ticket_id is not a number, to avoid query, below if condition is used.
  validate :valid_ticket?, if: -> { errors[:ticket_id].blank? && @ticket_id_set }, on: :create

  # User specific validations
  # agent_id can't be changed in update if timer is running for the user.
  validates :agent_id, inclusion: { in: [nil], message: 'cant_update_user' },
                       if: -> { item.timer_running && @agent_id_set && item.user_id != agent_id }, on: :update
  validates :agent_id, numericality: true, allow_nil: true, if: -> { errors[:agent_id].blank? }

  # if agent_id is not a number or not set in update, to avoid query, below if condition is used.
  validate :valid_user?,  if: -> { errors[:agent_id].blank? && @agent_id_set }

  def initialize(request_params, item, timer_running)
    super(request_params, item)
    check_params_set(request_params, item)
    @request_params = request_params
    @item = item
    @time_spent = request_params['time_spent']
    @start_time = request_params['start_time']
    @timer_running = timer_running
  end

  private

    def valid_ticket?
      @ticket = Account.current.tickets.find_by_param(request_params['ticket_id'], Account.current)
      errors.add(:ticket_id, :blank) unless @ticket
    end

    def valid_user?
      user = Account.current.agents_from_cache.find { |x| x.user_id == @agent_id } if @agent_id_set
      errors.add(:agent_id, :blank) unless user
    end

    def disallow_reset_timer_value
      errors.add(:timer_running, 'timer_running_duplicate') if request_params[:timer_running].to_s.to_bool == item.timer_running.to_s.to_bool
    end

    def start_time_value
      errors.add(:start_time, 'start_time_lt_now') if start_time.to_time.utc > Time.now.utc
    end

    def attributes_to_be_stripped
      TimeSheetConstants::FIELDS_TO_BE_STRIPPED
    end
end
