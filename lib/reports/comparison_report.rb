module Reports::ComparisonReport
	
  include Reports::ReportFields
  include TicketConstants
  include Reports::Constants
  include Helpdesk::Ticketfields::TicketStatus
  include Reports::HelpdeskReportingQuery

  #  Comparison report always goes to Redshift

  def comparison_data(condition , group_by)
    return if params[:comparison_selected].blank?                                 
  	selected_comparison = params[:comparison_selected].split(',') 
  	select_col_str,charts_data_hash = [],{}
    charts_data_hash.store('selected_comparison',selected_comparison.clone)
    selected_comparison.push('resolved_tickets') unless selected_comparison.include?('resolved_tickets')

    charts_data_hash.store("comparison_field",Reports::Constants.comparison_metrics)
    #constructing the select query array for str
  	selected_comparison.each do |comparison_field|
      if "backlog_tickets".eql?(comparison_field)
        select_col_str.push(%(backlog_tickets,true))  
        next
      end
  		select_col_str.push(comparison_field)
  	end
    select_col_str.push('first_resp_tickets')

    data_obj = comparison_report(condition,{ :select_columns => select_col_str.join(';'),
                :group_by => group_by})
    prepare_charts_data_hash(selected_comparison,charts_data_hash,data_obj,group_by)
  end

  def prepare_charts_data_hash(selected_comparison,charts_data_hash,data_obj,group_by)
    chart_label = get_labels(params[:members_selected].split(','),group_by)
    #constructing the chart data for each selected comparison.
    selected_comparison.each do |comparison_field|
      charts_data_hash.store(comparison_field+"_yAxis_label",
      Reports::Constants.comparison_metrics_labels[comparison_field.to_sym])
      if(comparison_field.include?("avg_") || COMPARISON_PERCENTAGE_FIELDS.include?(comparison_field.to_sym))
        charts_data_hash.store(comparison_field+"_bar",
          prepare_avg_bar_data_series(data_obj,
            {:label_column => group_by,:count_column => comparison_field},chart_label))

        charts_data_hash.store(comparison_field+"_line",
          prepare_line_data_series(data_obj,
            {:label_column => group_by, :count_column => comparison_field},chart_label,false,true))
      else
        charts_data_hash.store(comparison_field+"_bar",
          prepare_bar_data_series(data_obj,
            {:label_column => group_by,:count_column => comparison_field},chart_label))

        charts_data_hash.store(comparison_field+"_line",
          prepare_line_data_series(data_obj,
            {:label_column => group_by, :count_column => comparison_field},chart_label))
      end  
    end
    charts_data_hash
  end

  def prepare_avg_bar_data_series(data_obj,columns,chart_label,calculate_percent = false)
    data_hash, index,column_sum = {}, 0,{}
    line_color = ['#98b954','#4a7ebb','#be4b48','#3ba4c1','#80699b']

    chart_label.each do |key,val|
      data_hash[key.to_s] = {:name=>val,:color=>line_color[index],:data=>[]}
      column_sum[key.to_s] = {:column_total => 0, :tickets_sum =>0}
      index += 1
    end
    total_tkts_col = columns[:count_column].eql?("avg_first_response_time") ? 
            'first_responded_tickets' : 'resolved_tickets'
    data_obj.each do |tkt|
      next if tkt['created_at'].nil?
      column_sum["#{tkt[columns[:label_column]]}"][:column_total] += 
              tkt[columns[:count_column]].to_f unless tkt[columns[:count_column]].nil?

      column_sum["#{tkt[columns[:label_column]]}"][:tickets_sum] += 
              tkt[total_tkts_col].to_i unless tkt[columns[:count_column]].nil?
    end
    data_hash.each_pair do |key,val_hash|
      
      data_val = (column_sum[key][:tickets_sum] == 0) ? 0 : 
         ('%.2f' % (column_sum[key][:column_total]/column_sum[key][:tickets_sum])).to_f

      if columns[:count_column].eql?('avg_agent_interactions')
        val_hash[:data][0] = data_val
      elsif COMPARISON_PERCENTAGE_FIELDS.include?(columns[:count_column].to_sym)
        val_hash[:data][0] = data_val*100
      else
        val_hash[:data][0] = ('%.2f' % (data_val/3600)).to_f
      end
    end
    data_hash.values
  end

  def prepare_bar_data_series(data_obj,columns,chart_label,calculate_percent = false)
    data_hash, index = {}, 0
    line_color = ['#98b954','#4a7ebb','#be4b48','#3ba4c1','#80699b']
    backlog_col = columns[:count_column].eql?('backlog_tickets')

    chart_label.each do |key,val|
      data_hash[key.to_s] = {:name=>val,:color=>line_color[index],:data=>[0]}
      index += 1
    end

    data_obj.each do |tkt|
      next if tkt['created_at'].nil?
      data_hash["#{tkt[columns[:label_column]]}"][:data][0] = tkt[columns[:count_column]].to_i if backlog_col && tkt['created_at'] == @end_time
      data_hash["#{tkt[columns[:label_column]]}"][:data][0] += tkt[columns[:count_column]].to_i unless tkt[columns[:count_column]].nil? or backlog_col
    end
    data_hash.values
  end

  def prepare_line_data_series(data_obj,columns,chart_label,calculate_percent = false,isAvgReport=false)
    data_hash, dates_with_data, index = {}, {}, 0
    line_color = ['#98b954','#4a7ebb','#be4b48','#3ba4c1','#80699b']

    chart_label.each_pair do |key,val|
      data_hash[key.to_s] = {:name=>val,:type=>'line',:color=>line_color[index],:data=>[]}
      index += 1
    end

    #Storing the dates having data
    data_obj.each do |tkt|
      next if tkt['created_at'].nil?
      time_in_millis = Time.parse("#{tkt['created_at']}").to_i*1000
      dates_with_data[time_in_millis] ||= {}
      if(isAvgReport)       
        total_tkts_col = columns[:count_column].eql?("avg_first_response_time") ? 
            'first_responded_tickets' : 'resolved_tickets'
        data_val = tkt[total_tkts_col].to_i == 0 ? 0 :
              ('%.2f' % (tkt[columns[:count_column]].to_f / tkt[total_tkts_col].to_i)).to_f
        if columns[:count_column].eql?('avg_agent_interactions')
          dates_with_data[time_in_millis]["#{tkt[columns[:label_column]]}"] = data_val
        elsif COMPARISON_PERCENTAGE_FIELDS.include?(columns[:count_column].to_sym)
          dates_with_data[time_in_millis]["#{tkt[columns[:label_column]]}"] = data_val*100 
        else
          dates_with_data[time_in_millis]["#{tkt[columns[:label_column]]}"] = data_val/3600            
        end
      else
        dates_with_data[time_in_millis]["#{tkt[columns[:label_column]]}"] = tkt[columns[:count_column]].to_i
      end
    end

    #Pushing the dates with 0 tickets in an order

    this_date, report_end_date = Time.parse(start_date(false)), Time.parse(end_date(false))
    until this_date >= (report_end_date.since 1.day)
      this_date_in_millies = this_date.to_i*1000
      date_exists = dates_with_data.key?(this_date_in_millies)
      data_hash.each_pair do |key, val_hash|
        if date_exists && dates_with_data[this_date_in_millies].key?(key)
          val_hash[:data].push([this_date_in_millies,dates_with_data[this_date_in_millies][key]])
        else
          val_hash[:data].push([this_date_in_millies,0])
        end
      end
      this_date = this_date.since 1.day
    end
    data_hash.values
  end

end