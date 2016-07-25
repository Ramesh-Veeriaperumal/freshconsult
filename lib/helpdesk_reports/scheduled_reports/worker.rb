class HelpdeskReports::ScheduledReports::Worker
  include HelpdeskReports::Helper::Ticket
  
  attr_accessor :task, :report_filter, :report_type, :date_range
  
  def initialize task
    @task = task
    @report_filter = task.schedulable
    report_filter.data_hash.symbolize_keys!
    @report_type = HelpdeskReports::Constants::Common::REPORT_ENUM_TO_TYPE[report_filter.report_type]
    TimeZone.set_time_zone
  end

  def perform
    build_date_range
    params = old_report? ? build_params_old_report : build_params
    trigger_export(params)
  end
  
private

  def trigger_export(params)
    class_name = old_report? ? report_type.to_s.camelcase : 'Report'
    "HelpdeskReports::Export::#{class_name}".constantize.new(params, task).perform
  end

  def old_report?
    [:timesheet_reports, :chat_summary, :phone_summary].include?(report_type)
  end

  def build_params_old_report
    params = {
      date_range: date_range,
      report_type: report_type,
      filter_name: report_filter.filter_name,
      data_hash: report_filter.data_hash,
    }
  end

  def build_params
    report_filter.data_hash[:date_range] = date_range
    report_filter.data_hash[:filter_name] = report_filter.filter_name
    param_constructor = "HelpdeskReports::ParamConstructor::#{report_type.to_s.camelcase}".constantize.new(report_filter.data_hash)
    param_constructor.build_pdf_params
  end
  
  def build_date_range
    report_filter.data_hash.inspect
    if(report_filter.data_hash.nil? || report_filter.data_hash[:date].nil? || !report_filter.data_hash[:date]["presetRange"].present?)
      build_default_date_range 
    elsif(report_filter.data_hash[:date]["period"])
      build_period_date_range 
    else
      build_normal_date_range
    end
  end

  def build_period_date_range
    date_lag = old_report? ? 0 : (disable_date_lag? ? 0 : 1) 
    current_time = Time.zone.now
    lagged_time = current_time - date_lag.days
    start_day, end_day = nil, lagged_time
    case report_filter.data_hash[:date]["period"]
      when "today"
        start_day = lagged_time
      when "yesterday"
        start_day, end_day = (current_time - 1.day), (current_time - 1.day)
      when "this_week"
        start_day = current_time.beginning_of_week
      when "previous_week"
        start_day, end_day = (current_time  - 1.week).beginning_of_week, (current_time - 1.week).end_of_week
      when "this_month"
        start_day = current_time.beginning_of_month
      when "previous_month"
        start_day, end_day = (current_time - 1.month).beginning_of_month, (current_time - 1.month).end_of_month
      when "last_3_months"
        start_day = (lagged_time - 2.months).beginning_of_month
      when "last_6_months"
        start_day = (lagged_time - 5.months).beginning_of_month
      when "this_year"
        start_day = current_time.beginning_of_year
      else
        start_day = lagged_time - report_filter.data_hash[:date]["date_range"].to_i.days
    end
    @date_range = (end_day.to_date < start_day.to_date) ? nil : "#{date_format(start_day)} - #{date_format(end_day)}"
  end

  def build_normal_date_range
    current_time = Time.zone.now
    date_lag = old_report? ? 0 : (disable_date_lag? ? 0 : 1) 
    lagged_time = current_time - date_lag.days
    start_day, end_day = nil, lagged_time
    case report_filter.data_hash[:date]["date_range"]
      when 0
        start_day, end_day = current_time, current_time if date_lag.zero?
      when 1
        start_day, end_day = (current_time - 1.day), (current_time - 1.day)
      else
        start_day = lagged_time - report_filter.data_hash[:date]["date_range"].to_i.days
    end 
    if(start_day.nil?)
      @date_range = date_format(end_day)
    else
      @date_range = "#{date_format(start_day)} - #{date_format(end_day)}"
    end
  end

  def build_default_date_range
    date_lag = old_report? ? 0 : (disable_date_lag? ? 0 : 1) 
    current_time = Time.zone.now - date_lag.days
    start_day, end_day = current_time - 1.month, current_time
    @date_range = "#{date_format(start_day)} - #{date_format(end_day)}"
  end

  def date_format date
    date.strftime("%e %b, %Y")
  end

end
