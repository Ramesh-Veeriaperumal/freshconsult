class Helpdesk::ScheduledTask < ActiveRecord::Base
  self.primary_key = :id
  self.table_name =  "scheduled_tasks"
  
  concerned_with :constants, :validations

  belongs_to_account
  belongs_to :user
  belongs_to :schedulable, polymorphic: true

  has_many :schedule_configurations, :dependent => :delete_all, :autosave => true

  attr_protected :account_id, :user_id

  before_create :set_user_id
  before_save :mark_available, if: :schedule_changed?
  before_save :calculate_next_run_at, :update_last_run_at
  #callbacks commit/update - save inside leads to infinte loop
  after_commit :trigger, if: :available?

  scope :by_schedulable_type, lambda{ |schedulable_type| {:conditions => ['schedulable_type = ?', schedulable_type]}}

  scope :upcoming_tasks, lambda{ |from = Time.now.utc| 
    tasks_between(from, (from + CRON_FREQUENCY_IN_HOURS).end_of_hour).where(
      status: STATUS_NAME_TO_TOKEN[:available]) }

  scope :dangling_tasks, lambda{ |from = Time.now.utc| 
    tasks_between(from-2*CRON_FREQUENCY_IN_HOURS, from-30.minutes).where(
      "status NOT IN (?)", INACTIVE_STATUS) }

  scope :tasks_between, lambda{ |from, till| {
            :conditions => [ 'next_run_at BETWEEN ? AND ?', from, till ],
            :include => [:user, :account] }}

  INACTIVE_STATUS = [ STATUS_NAME_TO_TOKEN[:disabled], STATUS_NAME_TO_TOKEN[:expired] ]

  STATUS_NAME_TO_TOKEN.each_pair do |k, v|
    define_method("#{k}?") do
      status == v
    end
  end

  FREQUENCY_NAME_TO_TOKEN.each_pair do |k, v|
    define_method("#{k}?") do
      frequency == v
    end
  end

  SCHEDULABLE_ALIAS.each_pair do |k, v|
    define_method("#{v}?") do
      schedulable_type == k
    end
  end

  STATUS_NAME_TO_TOKEN.each_pair do |k, v|
    define_method("mark_#{k}") do
      self.status = v
      self
    end
  end

  def frequency_name
    FREQUENCY_TOKEN_TO_NAME[frequency]
  end

  def schedulable_name
    SCHEDULABLE_ALIAS[schedulable_type]
  end

  def status_name
    STATUS_TOKEN_TO_NAME[status]
  end

  def active?
    !(disabled? || expired? || end_date < Time.now.utc)
  end

  def start_date
    s_d = self[:start_date] || self[:created_at] || Time.now.beginning_of_day
    s_d.utc
  end

  def end_date
    e_d = self[:end_date] || (Time.now.beginning_of_day + 5.years)
    e_d.utc
  end

  def minute_of_day
    m_o_d = self[:minute_of_day]
    range_end = (frequency_name == :hourly) ? 59 : 1439
    (0..range_end).include?(m_o_d) ? m_o_d : 0
  end

  def day_of_frequency
    d_o_f = self[:day_of_frequency]
    case frequency_name
    when :weekly
      (0..6).include?(d_o_f) ? d_o_f : 0 #Sunday
    when :monthly
      (1..31).include?(d_o_f) ? d_o_f : 1
    else
      1
    end
  end

  def repeat_frequency
    r_f = self[:repeat_frequency]
    (1..30).include?(r_f) ? r_f : 1
  end

  def increment_consecutive_failuers
    self.consecutive_failuers = self.consecutive_failuers.to_i + 1
    if consecutive_failuers >= CONSECUTIVE_FAILUERS_LIMIT
      self.status = STATUS_NAME_TO_TOKEN[:disabled]
    end
    self
  end

  def reset_consecutive_failuers
    self.consecutive_failuers = 0
    self
  end

  def completed! run_status
    mark_available if in_progress?
    if run_status == false
      increment_consecutive_failuers
    else
      reset_consecutive_failuers
    end
    save!
  end

  def worker
    SCHEDULABLE_WORKER[schedulable_name]
  end

  def trigger(schedule_time = next_run_at)
    return unless (active? && worker.present?)
    return if schedule_time > (Time.now.utc.end_of_hour + CRON_FREQUENCY_IN_HOURS)

    from_now = (schedule_time - Time.now.utc).to_i
    from_now = 15 unless from_now > 15
    options = { account_id: account_id, task_id: id, next_run_at: next_run_at.to_i }
    mark_enqueued.save!
    worker.perform_in(from_now, options)
  end

  def as_json(options = {}, config = true)
    options[:except] = [:account_id]
    options[:include] ||= {}
    options[:include][:schedule_configurations] = Helpdesk::ScheduleConfiguration::JSON_OPTIONS if config
    super(options).merge!(:enabled => active?)
  end

  private

  def set_user_id
    self.user_id = User.current.id if User.current
  end

  def schedule_changed?
    new_record? || minute_of_day_changed? || day_of_frequency_changed? || 
      frequency_changed? || repeat_frequency_changed? || end_date_changed? || next_run_at_changed?
  end

  def calculate_next_run_at
    if schedule_changed? || (available? && status_changed?)
      self.next_run_at = find_next_schedule
      if next_run_at > end_date
        self.next_run_at = nil
        mark_expired
      end
    end
  end

  def update_last_run_at
    self.last_run_at =  Time.now.utc if in_progress? && status_changed?
    self
  end

  def find_next_schedule
    self.user.make_current if self.user
    TimeZone.set_time_zone
    upcoming_schedule(get_base_time).utc
  end

  def get_base_time
    if next_run_at.present? && !schedule_changed?
      Time.zone.parse(next_run_at.to_s)
    elsif (Time.now.utc - start_date) < 1.day #Skip more than a day outdated!
      to_frequency(Time.zone.parse(start_date.to_s))
    else
      to_frequency(Time.zone.now)
    end
  end

  def to_hourly(base_time)
    base_time.beginning_of_hour + minute_of_day.minute
  end

  def to_daily(base_time)
    base_time.beginning_of_day + minute_of_day.minute
  end

  def to_weekly(base_time)
    (base_time.end_of_week - 1.week).beginning_of_day + day_of_frequency.day + minute_of_day.minute
  end

  def to_monthly(base_time)
    last_mday = base_time.end_of_month.mday
    mday = (day_of_frequency > last_mday) ? last_mday : day_of_frequency
    base_time.beginning_of_month + (mday - 1).day + minute_of_day.minute
  end

  def to_frequency(base_time)
    case frequency_name
    when :hourly
      to_hourly(base_time) 
    when :weekly
      to_weekly(base_time)
    when :monthly
      to_monthly(base_time)
    else
      to_daily(base_time)
    end
  end

  def upcoming_schedule(prev_schedule)
    return prev_schedule if prev_schedule > Time.zone.now

    next_at = prev_schedule + (repeat_frequency * FREQUENCY_UNIT[frequency_name])
    next_at = to_monthly(next_at) if monthly?
    (next_at > Time.zone.now) ? next_at : upcoming_schedule(next_at)
  end

end
