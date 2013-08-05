module Reports::TopNAnalysisReport
	
	include Reports::ReportFields
  include TicketConstants
  include Reports::Constants
  include Helpdesk::Ticketfields::TicketStatus
  include Reports::HelpdeskReportingQuery


  
  def top_n_analysis_data(columns_arr,conditions,group_by,order)
    data_hash  = {}
    columns_arr.each do |chart_hash|
      order_by = chart_hash[:calculate_percent] ? "#{chart_hash[:count_column]}_percentage" :
                 "#{chart_hash[:count_column]}"
      order    = order.nil? ? chart_hash[:order] : order
      tickets_count = top_n_analysis(conditions,
        {:select_columns => chart_hash[:selet_columns],
          :order_by => "#{order_by} #{order}",
          :group_by => group_by, :limit => 5})
      data_hash.store(chart_hash[:id],
        prepare_data_series(chart_hash[:label_name],tickets_count,
          {:label_column => group_by , 
            :count_column => chart_hash[:count_column]},
            chart_hash[:calculate_percent],
            chart_hash[:is_rating],
            chart_hash[:is_time_column]))
    end
    return data_hash
  end

  def prepare_data_series(name,series_array,columns,calculate_percent = false,is_rating=false,is_time_column=false)
    xaxis_id_arr, xaxis_name_arr, data_array, xaxis_Hash = [], [], [], {}
    # fetching the group/agent ids
    xaxis_id_arr = series_array.map {|h| h[columns[:label_column]]}
    #generating hash with group/agent id name maping.
    xaxis_Hash = get_labels(xaxis_id_arr,columns[:label_column])

    series_array.each do |tkt|
      label_column_value = xaxis_Hash[tkt[columns[:label_column]].to_i] 
      xaxis_name_arr.push(label_column_value)
      if calculate_percent
        percrntage = tkt[columns[:count_column]+'_percentage'].nil? ? 
        0 : tkt[columns[:count_column]+'_percentage'].to_f*100
        
        data_array.push({:y => sprintf("%0.02f",percrntage).to_f, 
          :name=> label_column_value,
          :count => is_rating ? tkt[columns[:count_column]].to_s+" of #{tkt['total_count']} Rated" : 
           sprintf("%0.02f",percrntage).to_s+" of #{tkt['total_count']} Resolved",
          :tool_tip_label => is_rating ?tkt[columns[:count_column]].to_s+" of #{tkt['total_count']} Rated Ticket(s)" :
           sprintf("%0.02f",percrntage).to_s+"% of #{tkt['total_count']} Resolved Ticket(s)"})

      elsif is_time_column
        data_array.push({:y => (tkt[columns[:count_column]].to_i/3600), :name => label_column_value,
          :count => tkt[columns[:count_column]].to_s+" hr(s) per",
          :tool_tip_label => (tkt[columns[:count_column]].to_i/3600).to_s+" hr(s) per ticket."})
      else
        data_array.push({:y => tkt[columns[:count_column]].to_i, :name => label_column_value,
          :count => tkt[columns[:count_column]]})
      end
    end
    return {:xaxis_arr => xaxis_name_arr, 
            :chartData=>data_array,
            :title => name,
            :yAxisLabel => calculate_percent ? I18n.t("adv_reports.comparison_reports.label_in_percentage") : 
            is_time_column ? 'in Hr(s)' : I18n.t("adv_reports.comparison_reports.label_num_of_tickets")}
  end

end