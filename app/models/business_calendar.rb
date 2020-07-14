# encoding: utf-8
#Well, it is not a sexy name, but everything else is taken by business_time plugin.

class BusinessCalendar < ActiveRecord::Base
  include BusinessCalenderConstants

  self.primary_key = :id

  include MemcacheKeys
  serialize :business_time_data
  serialize :holiday_data

  after_find :set_business_time_data
  after_create :set_business_time_data

  #business_time_data has working days and working hours inside.
  #for now, a sporadically structured hash is used.
  #can revisit this data model later...
  belongs_to_account
  before_create :set_default_version, :valid_working_hours?
  after_commit ->(obj) {
      obj.clear_cache
      update_livechat_bc_data
    }, on: :update

  # ##### Added to mirror db changes in helpkit to freshchat db
  after_commit ->(obj) {
      obj.clear_cache
      remove_livechat_bc_data
    }, on: :destroy
  ####

  attr_accessible :holiday_data, :business_time_data, :version, :is_default, :name, :description, :time_zone
  validates_presence_of :time_zone, :name

  concerned_with :presenter

  scope :default, :conditions => { :is_default => true }

  xss_sanitize :only => [:name, :description]

  def business_intervals
    interval = {}
    working_hours.each do |day, business_hour|
      interval[BusinessCalenderConstants::WEEKDAY_HUMAN_LIST[day-1]] = {
          start_time: business_hour[:beginning_of_workday],
          end_time: business_hour[:end_of_workday]
      }
    end
    interval
  end

  def time_zone
    tz = self.read_attribute(:time_zone)
    tz = "Kyiv" if tz.eql?("Kyev")
    tz
  end

  # setting correct timezone and business_calendar based on the context of the ticket getting updated
  def self.execute(groupable, options = {})
    begin
      zone = current_time_zone(groupable)
      Time.use_zone(zone) {
        Rails.logger.debug "Timezone:: #{zone}"
        yield
      }
    rescue Exception => e
      groupable.sla_on_background = true if options[:dueby_calculation] && groupable.respond_to?(:sla_on_background=)
      NewRelic::Agent.notice_error(e)
    ensure
      Thread.current[TicketConstants::BUSINESS_HOUR_CALLER_THREAD] = nil
    end
  end

  def self.current_time_zone(groupable)
    group = groupable.try(:group)
    Thread.current[TicketConstants::BUSINESS_HOUR_CALLER_THREAD] = group
    calendar = Group.default_business_calendar(group)
    calendar.time_zone
  end
  # setting correct timezone and business_calendar based on the context of the ticket ends here

  def beginning_of_workday day
    business_hour_data[:working_hours][day][:beginning_of_workday]
  rescue StandardError => e
    Rails.logger.error "Business Hours : #{id} : #{account_id}  : Error while trying to fetch start of work: #{e.inspect} #{e.backtrace.join("\n\t")}"
    '12:00 am'
  end

  def end_of_workday day
    business_hour_data[:working_hours][day][:end_of_workday]
  rescue StandardError => e
    Rails.logger.error "Business Hours : #{id} : #{account_id}  : Error while trying to fetch end of work: #{e.inspect} #{e.backtrace.join("\n\t")}"
    '12:00 am'
  end

  def end_of_day_in_date_time(day, time)
    @end_of_workday_date_time ||= Utils::SimpleLRUHash.new(365)
    @end_of_workday_date_time["#{day.day}-#{day.mon}-#{day.year}"] ||= formatted_date(day, time)
  end

  def beginning_of_day_in_date_time(day, time)
    @beginning_of_workday_date_time ||= Utils::SimpleLRUHash.new(365)
    @beginning_of_workday_date_time["#{day.day}-#{day.mon}-#{day.year}"] ||= formatted_date(day, time)
  end

  def weekdays
    business_hour_data[:weekdays]
  end

  def fullweek
    business_hour_data[:fullweek]
  end

  def holidays
    return [] if holiday_data.nil?
    calendar_holidays =[]
    holiday_data.each do |holiday|
      begin
        calendar_holidays << Date.parse(holiday[0])
      rescue StandardError => e
        Rails.logger.error "Business Hours : #{id} : #{account_id} : Error while trying to fetch hoilday list: #{e.inspect} #{e.backtrace.join("\n\t")}"
        next
      end
    end
    calendar_holidays
  end

  def working_hours
    business_hour_data[:working_hours]
  end

  def self.config
    if multiple_business_hours_enabled?
      @business_hour_caller.business_calendar
    elsif Account.current
      Account.current.default_calendar_from_cache
    else
      BusinessTime::Config
    end
  end

  def clear_cache
    key = DEFAULT_BUSINESS_CALENDAR % {:account_id => Account.current.id}
    MemcacheKeys.delete_from_cache key if self.is_default
  end

  def business_hour_data
    business_time_data || DEFAULT_SEED_DATA
  end

  #migration code starts here..
  def upgraded_business_time_data
    business_data = self.business_time_data
    business_time = BUSINESS_TIME_INFO.inject({}) {|h,v| h[v] = business_data[v]; h}
    business_time[:working_hours] = Hash.new
    business_time[:weekdays].each do |n|
      business_time[:working_hours][n] = WORKING_HOURS_INFO.inject({}) {|h,v| h[v] = business_data[v]; h}
    end
    self.version = 2
    return business_time
  end

  def set_business_time_data
    if version == 1
      self.business_time_data = upgraded_business_time_data
      self.save
    end
    self
  end

  def weekday_set
    @weekday_set ||= weekdays.to_set.freeze
  end

  def holiday_set
    @holiday_set ||= holidays.collect { |holiday| "#{holiday.day} #{holiday.mon}" }.to_set.freeze
  end

  private

    def formatted_date(day, time)
      format = "%B %d %Y #{time}"
      Time.zone ? Time.zone.parse(day.strftime(format)) : Time.parse(day.strftime(format))
    end

    def valid_working_hours?
      if (version != 1) && !weekdays.blank?
        weekdays.each do |n|
          errors.add(:base,"Enter a valid Time") if (Time.zone.parse(beginning_of_workday(n))  >
             Time.zone.parse(end_of_workday(n)))
        end
      else
        errors.add(:base,"Atleast one working day must be checked")
      end
    end

    def set_default_version
      self.version = 2
    end

    def self.multiple_business_hours_enabled?
      @business_hour_caller = Thread.current[TicketConstants::BUSINESS_HOUR_CALLER_THREAD]
      Account.current.multiple_business_hours_enabled? &&
       @business_hour_caller &&
       @business_hour_caller.business_calendar
    end

    def remove_livechat_bc_data
      calendar_data = nil
      update_livechat calendar_data
    end

    def update_livechat_bc_data
      calendar_data = JSON.parse(self.to_json({:only => [:time_zone, :business_time_data, :holiday_data]}))['business_calendar']
      update_livechat calendar_data
    end

    def update_livechat calendar_data
      if account.features?(:chat)
        widgets = account.chat_widgets.find(:all, :conditions => {:business_calendar_id => id})
        widgets.each do |widget|
          site_id = account.chat_setting.site_id
          LivechatWorker.perform_async(
            {
              :worker_method => "update_widget",
              :widget_id => widget.widget_id,
              :siteId => site_id,
              :attributes => {:business_calendar => calendar_data}.to_json
            }
          )
        end
      end
    end

end
