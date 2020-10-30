# encoding: utf-8
#Well, it is not a sexy name, but everything else is taken by business_time plugin.

class BusinessCalendar < ActiveRecord::Base
  include BusinessCalenderConstants

  SYNC_FAILURE = 'failed to sync'.freeze

  self.primary_key = :id

  include MemcacheKeys
  serialize :business_time_data
  serialize :holiday_data
  serialize :additional_settings, Hash

  validates :name, uniqueness: { scope: :account_id }, if: :name_changed?

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
  after_commit -> { omni_business_calendar_sync(:create) }, on: :create, if: -> { Account.current.omni_business_calendar? }
  after_commit -> { omni_business_calendar_sync(:update) }, on: :update, if: lambda {
    Account.current.omni_business_calendar? &&
        channel_bc_api_params.present? && channel_bc_api_params.is_a?(Array)
  }
  after_commit -> { omni_business_calendar_sync(:delete) }, on: :destroy, if: -> { Account.current.omni_business_calendar? }

  attr_accessor :channel_bc_api_params, :freshchat_business_hours, :freshcaller_business_hours
  attr_accessible :holiday_data, :business_time_data, :version, :is_default, :name, :description, :time_zone
  validates_presence_of :time_zone, :name

  concerned_with :presenter

  scope :default, -> { where(is_default: true) }

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

  def edit_mint_url
    "#{account.url_protocol}://#{account.host}/a/admin/business_calendars/#{id}/edit"
  end

  def channel_bussiness_hour_data
    channel_business_hours = []
    channel_business_hours << freshdesk_business_hour_data
    if Account.current.omni_business_calendar?
      channel_business_hours << freshchat_business_hour_data
      channel_business_hours << freshcaller_business_hour_data
    end
    channel_business_hours
  end

  def freshdesk_business_hour_data
    data = {}.with_indifferent_access
    data[:channel] = ApiBusinessCalendarConstants::TICKET_CHANNEL
    data[:business_hours_type] = business_time_data[:fullweek] ? ApiBusinessCalendarConstants::ALL_TIME_AVAILABLE : ApiBusinessCalendarConstants::CUSTOM_AVAILABLE
    if data[:business_hours_type] == ApiBusinessCalendarConstants::CUSTOM_AVAILABLE
      data[:business_hours] = business_time_data[:weekdays].each_with_object([]) do |day, array|
        array << { day: BusinessCalenderConstants::WEEKDAY_HUMAN_LIST[day - 1], time_slots: time_slots(day) }
      end
    end
    data
  end

  def freshchat_business_hour_data
    if freshchat_business_hours.present?
      data = freshchat_business_hours
    else
      data = {}.with_indifferent_access
      data[:channel] = ApiBusinessCalendarConstants::CHAT_CHANNEL
    end
    data[:sync_status] = sync_freshchat_status || OMNI_SYNC_STATUS[:inprogress]
    data
  end

  def freshcaller_business_hour_data
    if freshcaller_business_hours.present?
      data = freshcaller_business_hours
    else
      data = {}.with_indifferent_access
      data[:channel] = ApiBusinessCalendarConstants::PHONE_CHANNEL
    end
    data[:sync_status] = sync_freshcaller_status || OMNI_SYNC_STATUS[:inprogress]
    data
  end

  def time_slots(day)
    [{ start_time: time_in_24hr_format(business_time_data[:working_hours][day][:beginning_of_workday]), end_time: time_in_24hr_format(business_time_data[:working_hours][day][:end_of_workday]) }]
  end

  def sync_freshcaller_status
    additional_settings.try(:[], 'sync_freshcaller_results').try(:[], 'status')
  end

  def sync_freshchat_status
    additional_settings.try(:[], 'sync_freshchat_results').try(:[], 'status')
  end

  def sync_freshcaller_action
    additional_settings.try(:[], 'sync_freshcaller_results').try(:[], 'action')
  end

  def sync_freshchat_action
    additional_settings.try(:[], 'sync_freshchat_results').try(:[], 'action')
  end

  def set_sync_channel_status(channel, action, status)
    self.additional_settings = (self.additional_settings ||= {}).merge!(
                                                                         {
                                                                           "sync_#{channel}_results" => {
                                                                             "status" => status,
                                                                             "action" => action
                                                                           }
                                                                         }
                                                                       )
  end

  def update_sync_status_without_callbacks(channel, action, status)
    settings = (self.additional_settings ||= {}).merge!(
      {
          "sync_#{channel}_results" => {
              "status" => status,
              "action" => action.to_s
          }
      }
    )
    self.update_column('additional_settings', settings.to_yaml)
  end

  def fetch_omni_business_calendar
    [ApiBusinessCalendarConstants::API_CHANNEL_TO_PRODUCT[ApiBusinessCalendarConstants::PHONE_CHANNEL],
    ApiBusinessCalendarConstants::API_CHANNEL_TO_PRODUCT[ApiBusinessCalendarConstants::CHAT_CHANNEL]].each do |channel|
      sync_success, service_unavailable, response = fetch_business_calendar_from_channel(channel)
      return if service_unavailable
      self.safe_send("#{channel}_business_hours=", response['channel_business_hours'].try(:[], 0)) if sync_success
    end
  rescue StandardError => e
    NewRelic::Agent.notice_error(e, args: "#{account_id}: Exception in omni business calendar GET")
  end

  private

    def formatted_date(day, time)
      format = "%B %d %Y #{time}"
      Time.zone ? Time.zone.parse(day.strftime(format)) : Time.parse(day.strftime(format))
    end

    def time_in_24hr_format(time)
      DateTime.parse(time).utc.strftime('%H:%M')
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
        widgets = account.chat_widgets.where(business_calendar_id: id)
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

    def fetch_business_calendar_from_channel(name)
      channel_sync_obj = Omni::SyncFactory.fetch_bc_sync(channel: name, resource_id: id, action: :get, performed_by_id: User.current.id)
      channel_response = channel_sync_obj.sync_channel
      channel_sync_success = channel_sync_obj.response_success?
      channel_service_unavailable = channel_sync_obj.service_unavailable_response?
      if !channel_sync_success && channel_service_unavailable
        Rails.logger.info "Omni Business calendar #{name} GET request failed as service unavailable"
        errors.add("#{name}_business_hours".to_sym, "Omni Business Calendar fetch for #{name} failed")
      end
      [channel_sync_success, channel_service_unavailable, channel_response]
    end

    def omni_business_calendar_sync(action, channel = nil, performer_id = nil)
      Rails.logger.info 'Omni Business calendar sync started'
      if Account.current.present? && User.current.nil? && performer_id.present?
        user = Account.current.users.find(performer_id)
        user.make_current if user.present?
      end
      method_params = { id: id, performed_by_id: User.current.id }
      method_params.merge!(params: safe_send("#{action.to_s}_params")) if [:create, :update].include?(action)

      freshcaller_action = channel_action(ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT, action)
      freshchat_action = channel_action(ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT, action)
      if channel.nil? || channel.to_s == ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT
        caller_job_id = Admin::BusinessCalendar::OmniSyncWorker.perform_async(method_params.merge(
                                                                                channel: ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT,
                                                                                action: freshcaller_action
                                                                              ))
        update_sync_status_without_callbacks(ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT, freshcaller_action, OMNI_SYNC_STATUS[:inprogress]) if action != :delete
      end
      reload if action != :delete
      if channel.nil? || channel.to_s == ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT
        chat_job_id = Admin::BusinessCalendar::OmniSyncWorker.perform_async(method_params.merge(
                                                                              channel: ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT,
                                                                              action: freshchat_action
                                                                            ))
        update_sync_status_without_callbacks(ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT, freshchat_action, OMNI_SYNC_STATUS[:inprogress]) if action != :delete
      end
      Rails.logger.info "caller_job_id #{caller_job_id}, chat_job_id #{chat_job_id}"
    rescue StandardError => e
      update_sync_status_without_callbacks(ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT, freshcaller_action, OMNI_SYNC_STATUS[:failed])
      update_sync_status_without_callbacks(ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT, freshchat_action, OMNI_SYNC_STATUS[:failed])
      Rails.logger.info "Exception in omni_business_calendar_sync method #{e.message}"
      NewRelic::Agent.notice_error(exception, args: "#{account_id}: Exception in omni business calendar sync")
    end

    def channel_action(channel, action)
      safe_send("sync_#{channel}_status") == OMNI_SYNC_STATUS[:failed] ? safe_send("sync_#{channel}_action") : action
    end

    def create_params
      {
        name: name,
        description: description,
        time_zone: time_zone,
        default: is_default,
        holidays: holiday_data.map { |data| { name: data[1], date: data[0] } },
        channel_business_hours: channel_business_hours_params
      }
    end

    def channel_business_hours_params
      channel_bc_params = channel_bc_api_params || []
      request_channel_names = channel_bc_params.map { |channel_data| channel_data['channel'] }
      (ApiBusinessCalendarConstants::VALID_CHANNEL_PARAMS_OMNI - request_channel_names).each { |channel| channel_bc_params << default_channel_business_hours(channel) }
      channel_bc_params
    end

    def default_channel_business_hours(channel)
      data = {}.with_indifferent_access
      data[:channel] = channel
      data[:business_hours_type] = ApiBusinessCalendarConstants::CUSTOM_AVAILABLE
      data[:business_hours] = default_business_hours_data
      data[:away_message] = ApiBusinessCalendarConstants::CHAT_DEFAULT_AWAY_MESSAGE if channel == ApiBusinessCalendarConstants::CHAT_CHANNEL
      data
    end

    def default_business_hours_data
      DEFAULT_SEED_DATA[:weekdays].each_with_object([]) do |day, array|
        array << { day: BusinessCalenderConstants::WEEKDAY_HUMAN_LIST[day - 1], time_slots: [{ start_time: time_in_24hr_format(DEFAULT_SEED_DATA[:working_hours][day][:beginning_of_workday]), end_time: time_in_24hr_format(DEFAULT_SEED_DATA[:working_hours][day][:end_of_workday]) }] }
      end
    end

    alias_method :update_params, :create_params
end
