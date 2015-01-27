# encoding: utf-8
#Well, it is not a sexy name, but everything else is taken by business_time plugin.

class BusinessCalendar < ActiveRecord::Base

  include MemcacheKeys
  serialize :business_time_data
  serialize :holiday_data
  
  #business_time_data has working days and working hours inside.
  #for now, a sporadically structured hash is used.
  #can revisit this data model later...
  belongs_to :account
  before_create :set_default_version, :valid_working_hours?

  after_commit_on_destroy :remove_livechat_bc_data
  after_commit_on_update :clear_cache, :update_livechat_bc_data
  
  attr_accessible :holiday_data,:business_time_data,:version,:is_default,:name,:description,:time_zone
  validates_presence_of :time_zone, :name

  named_scope :default, :conditions => { :is_default => true }

  xss_sanitize :only => [:name, :description]

  #needed for upgrading business_time_data - Abhinav
  BUSINESS_TIME_INFO = [:fullweek, :weekdays] 
  WORKING_HOURS_INFO = [:beginning_of_workday, :end_of_workday]
  #migration code ends

  TIME_LIST =[  "1:00" , "1:30" , "2:00" , "2:30" , "3:00" , 
                "3:30" , "4:00" , "4:30" , "5:00" , "5:30" ,
                "6:00" , "6:30" , "7:00" , "7:30" , "8:00" , 
                "8:30" , "9:00" , "9:30" , "10:00" , "10:30" , 
                "11:00" ,"11:30" ,"12:00", "12:30" 
              ]
  
  HOLIDAYS_SEED_DATA =[ ["Jan 16", "Birthday of Martin Luther King Jr"], 
                        ["Feb 20", "Washington’s Birthday"], 
                        ["May 28", "Memorial Day"],
                        ["Jul 04", "Independence Day"],
                        ["Sep 03", "Labor Day"],
                        ["Oct 08", "Columbus Day"],
                        ["Nov 11", "Veterans Day"],
                        ["Nov 22", "Thanksgiving Day"],
                        ["Dec 25", "Christmas Day"],
                        ["Jan 01", "New Year’s Day"]  ]
   
  DEFAULT_SEED_DATA = {
    :working_hours => { 1 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
                        2 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
                        3 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
                        4 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
                        5 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"}
                      },
    :weekdays => [1, 2, 3, 4, 5],
    :fullweek => false
  }  

  # setting correct timezone and business_calendar based on the context of the ticket getting updated
  def self.execute(groupable)
    begin
      set_time_zone(groupable)
      # do businesstime related stuff
      yield
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    ensure
      Thread.current[TicketConstants::BUSINESS_HOUR_CALLER_THREAD] = nil
      User.current ? set_user_time_zone : set_account_time_zone
    end 
  end

  def self.set_time_zone(groupable)
    begin
      group = groupable.respond_to?("group")? groupable.group : nil      
      account = groupable ? groupable.account : Account.current

      Thread.current[TicketConstants::BUSINESS_HOUR_CALLER_THREAD] = group
      
      return set_account_time_zone(account) unless account.features_included?(:multiple_business_hours)

      if group.nil? || group.business_calendar.nil?
        set_account_time_zone(account)
      else
        set_group_time_zone(group)
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
  end

  def self.set_account_time_zone(account=Account.current)
    Time.zone = account.time_zone    
  end

  def self.set_group_time_zone(group)
    Time.zone = group.business_calendar.time_zone
  end
 
  def self.set_user_time_zone
    Time.zone = User.current.time_zone  
  end
  # setting correct timezone and business_calendar based on the context of the ticket ends here

  def beginning_of_workday day
    business_hour_data[:working_hours][day][:beginning_of_workday]
  end
  
  def end_of_workday day
    business_hour_data[:working_hours][day][:end_of_workday]
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
      rescue
        #dont do anything, just skip the invalid holiday
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
      key = DEFAULT_BUSINESS_CALENDAR % {:account_id => Account.current.id}
      MemcacheKeys.fetch(key) do
        Account.current.business_calendar.default.first
      end
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

  def after_find
    if (version == 1) 
      self.business_time_data = upgraded_business_time_data 
      self.save
    end
  end
  #migrtation code ends..

  private 

    def valid_working_hours?
      if (version != 1) && !weekdays.blank?
        weekdays.each do |n|
          errors.add_to_base("Enter a valid Time") if (Time.zone.parse(beginning_of_workday(n))  >
             Time.zone.parse(end_of_workday(n)))
        end
      else
        errors.add_to_base("Atleast one working day must be checked")
      end
    end

    def set_default_version
      self.version = 2
    end

    def self.multiple_business_hours_enabled?
      @business_hour_caller = Thread.current[TicketConstants::BUSINESS_HOUR_CALLER_THREAD]
      Account.current.features?(:multiple_business_hours) &&
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
          site_id = account.chat_setting.display_id
          Resque.enqueue(Workers::Livechat, 
            {
              :worker_method => "update_widget", 
              :widget_id => widget.widget_id, 
              :siteId => site_id, 
              :attributes => { :business_calendar => calendar_data}
            }
          )
        end
      end
    end
end
