class Reports::Freshfone::SummaryReportsController < ApplicationController

  include Reports::FreshfoneReport
  #Added for export csv, call to methods using send
  include Reports::Freshfone::SummaryReportsHelper
  include ReportsHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  before_filter :access_denied, :unless => :freshfone_reports?
  before_filter :set_report_type
  before_filter :load_cached_filters, :report_filter_data_hash, :only => [:index]
  before_filter :set_cached_filters, :only => [:generate]
  before_filter :set_selected_tab, :build_criteria
  before_filter :set_filter, :only => [:index, :generate]
  before_filter :max_limit?, :only => [:save_reports_filter]
  before_filter :construct_filters,        :only => [:save_reports_filter,:update_reports_filter]

  around_filter :run_on_slave , :except => [:save_reports_filter,:update_reports_filter,:delete_reports_filter]


  attr_accessor :report_type

  def index
    #Render default index erb
  end

  def generate
    #Render default rjs
  end

  def export_csv
    @calls = filter(@start_date,@end_date)
    headers = csv_hash.keys.sort
    send_data csv_string(headers), :type => 'text/csv; charset=utf-8; header=present', 
            :disposition => "attachment; filename=phone_summary_report.csv"
  end

  def save_reports_filter
    report_filter = current_user.report_filters.build(
      :report_type => @report_type_id,
      :filter_name => @filter_name,
      :data_hash   => @data_map
    )
    report_filter.save
    
    render :json => {:text=> "success", 
                     :status=> "ok",
                     :id => report_filter.id,
                     :filter_name=> @filter_name,
                     :data=> @data_map }.to_json
  end

  def update_reports_filter
    id = params[:id].to_i
    report_filter = current_user.report_filters.find(id)
    report_filter.update_attributes(
      :report_type => @report_type_id,
      :filter_name => @filter_name,
      :data_hash   => @data_map
    )
    render :json => {:text=> "success", 
                     :status=> "ok",
                     :id => report_filter.id,
                     :filter_name=> @filter_name,
                     :data=> @data_map }.to_json
  end

  def delete_reports_filter
    id = params[:id].to_i
    report_filter = current_user.report_filters.find(id)
    report_filter.destroy 
    render json: "success", status: :ok
  end


  private 
  
    def run_on_slave(&block)
      Sharding.run_on_slave(&block)
    end 

    def set_filter
      @calls = filter(@start_date,@end_date)
      previous_time_range #setting the date range to previous time period 
      @old_calls = filter(@prev_start_time,@prev_end_time)
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
      CSVBridge.generate do |csv|
        csv << headers
        headers.shift #agent_name field removed to make a common method call send
        @calls.each do |call_list|
          csv_data = [call_list.agent_name]
          headers.each do |val|
            csv_data << column_data(val, [call_list])
          end
          csv << csv_data
        end
      end
    end

    def column_data(value, calls)
      column_value = send(csv_hash[value], calls) 
      column_value = call_duration_in_mins(column_value) if(date_time_fields.include?(csv_hash[value]))
      column_value
    end

    def set_selected_tab
      @selected_tab = :reports
    end

    def set_report_type
      @report_type = "phone_summary"
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
