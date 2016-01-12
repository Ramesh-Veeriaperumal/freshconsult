# Copyright © 2014 Freshdesk Inc. All Rights Reserved.
class Reports::Freshfone::SummaryReportsController < ApplicationController

  include ReadsToSlave

  include Reports::FreshfoneReport
  #Added for export csv, call to methods using send
  include Reports::Freshfone::SummaryReportsHelper
  include ReportsHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  before_filter :access_denied, :unless => :freshfone_reports?
  before_filter :load_cached_filters, :only => [:index]
  before_filter :set_cached_filters, :only => [:generate]
  before_filter :set_selected_tab, :build_criteria
  before_filter :set_filter ,:only => [:index, :generate]


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


  private 

    def set_filter
      @report_type = "phone_summary"
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
      params.merge!(@cached_filter)
    end

    def cached_params
      {'date_range' => params[:date_range],
       'freshfone_number' => params[:freshfone_number],
       'group_id' => params[:group_id],
       'call_type' => params[:call_type],
       'business_hours' => params[:business_hours]}
    end

end
