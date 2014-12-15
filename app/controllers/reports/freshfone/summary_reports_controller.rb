# Copyright © 2014 Freshdesk Inc. All Rights Reserved.
class Reports::Freshfone::SummaryReportsController < ApplicationController

  include ReadsToSlave

  include Reports::FreshfoneReport
  #Added for export csv, call to methods using send
  include Reports::Freshfone::SummaryReportsHelper
  include ReportsHelper

  before_filter :access_denied, :unless => :freshfone_reports?
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
            :disposition => "attachment; filename=freshfone_summary_report.csv"
  end


  private 

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

    def date_time_fields
      [:call_handle_time, :avg_handle_time]
    end

end
