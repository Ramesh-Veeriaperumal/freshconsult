class Reports::Freshfone::SummaryReportsController < ApplicationController

  include Reports::FreshfoneReport
  #Added for export csv, call to methods using send
  include Reports::Freshfone::SummaryReportsHelper
  include HelpdeskReports::Helper::ControllerMethods
  include ReportsHelper
  include Redis::RedisKeys
  include Redis::OthersRedis
  include HelpdeskReports::Helper::ScheduledReports
  include ExportCsvUtil

  before_filter :access_denied, :unless => :freshfone_reports?
  before_filter :set_report_type, :set_selected_tab
  before_filter :build_criteria,                                :except => [:export_pdf]
  before_filter :set_filter,                                    :only   => [:index, :generate]
  before_filter :save_report_max_limit?,                        :only   => [:save_reports_filter]
  before_filter :construct_report_filters, :schedule_allowed?,  :only   => [:save_reports_filter,:update_reports_filter]

  around_filter :run_on_slave , :except => [:save_reports_filter,:update_reports_filter,:delete_reports_filter]

  helper_method :enable_schedule_report?

  attr_accessor :report_type

  def index
    load_cached_filters
    report_filter_data_hash
    #Render default index erb
  end

  def generate
    set_cached_filters
    #Render default rjs
  end

  def export_csv
    @calls = filter(@start_date,@end_date)
    headers = csv_hash.keys.sort
    send_data csv_string(headers), :type => 'text/csv; charset=utf-8; header=present', 
            :disposition => "attachment; filename=phone_summary_report.csv"
  end

  def export_pdf
    params.merge!(:report_type => report_type)
    params.merge!(:portal_name => current_portal.name) if current_portal
    Reports::Export.perform_async(params)
    render json: nil, status: :ok
  end
  
  def save_reports_filter
    common_save_reports_filter    
  end

  def update_reports_filter
    common_update_reports_filter
  end

  def delete_reports_filter
    common_delete_reports_filter
  end

  private 
  
    def run_on_slave(&block)
      Sharding.run_on_slave(&block)
    end 

    def schedule_allowed?
      if params['data_hash']['schedule_config']['enabled'] == true 
        allow = enable_schedule_report? && current_user.privilege?(:export_reports)
        render json: nil, status: :ok if allow != true
      end
    end

    def csv_hash
      headers = { "Agent" => :agent_name,
        "Total Duration" => :call_handle_time,
        "Average Handle Time" => :avg_handle_time,
        "Answer %" => :answered_percentage,
        "Total Calls" => :calls_count }
      headers.merge!("Unanswered Calls" => :all_unanswered) if(@call_type.to_i == Freshfone::Call::CALL_TYPE_HASH[:incoming])
      headers
    end

    def csv_string(headers)
      csv_row_limit = HelpdeskReports::Constants::Export::FILE_ROW_LIMITS[:export][:csv]
      csv_size = @calls.size
      if (csv_size > csv_row_limit)
        @calls.slice!(csv_row_limit..(csv_size - 1)) 
        exceeds_row_limit = true
      end
      CSVBridge.generate do |csv|
        csv << headers
        headers.shift #agent_name field removed to make a common method call send
        @calls.each do |call_list|
          csv_data = [handle_operators(call_list.agent_name)]
          headers.each do |val|
            csv_data << column_data(val, [call_list])
          end
          csv << csv_data
        end
        csv << [t('helpdesk_reports.export_exceeds_row_limit_msg') % {:row_max_limit => csv_row_limit}] if exceeds_row_limit
      end
    end

    def column_data(value, calls)
      column_value = safe_send(csv_hash[value], calls) 
      column_value = call_duration_in_mins(column_value) if(date_time_fields.include?(csv_hash[value]))
      column_value
    end

    def set_selected_tab
      @selected_tab = :reports
    end

    def set_report_type
      @report_type         = :phone_summary
      @user_time_zone_abbr = Time.zone.now.zone
    end

    def date_time_fields
      [:call_handle_time, :avg_handle_time]
    end

    def reports_filter_key
      ADMIN_FRESHFONE_REPORTS_FILTER % {:account_id => current_account.id, :user_id => current_user.id}
    end

    def set_cached_filters
      set_others_redis_hash(reports_filter_key, cached_params)
      set_others_redis_expiry(reports_filter_key, 86400*7)
    end

    def load_cached_filters
      @cached_filter = get_others_redis_hash(reports_filter_key)
      prepare_filters
    end

    def cached_params
      {'date_range_type' => params[:date_range_type],
       'date_range' => params[:date_range], 
       'freshfone_number' => params[:freshfone_number],
       'group_id' => params[:group_id],
       'call_type' => params[:call_type],
       'business_hours' => params[:business_hours]}
    end

end
