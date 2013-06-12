module Reports::HelpdeskAnalysisReport
	
  include Reports::ReportFields
  include TicketConstants
  include Reports::Constants
  include Helpdesk::Ticketfields::TicketStatus
  include Reports::HelpdeskReportingQuery


  def analysis_report_data(conditions)
    data_hash = {}
    tickets_count = helpdesk_analysis_query(conditions, {:group_by => "report_table.created_at",
    :select_columns => "received_tickets;resolved_tickets;backlog_tickets,true" })
    time_of_arrival_tkts = helpdesk_analysis_query(conditions, 
      { :group_by => "report_table.created_hour, report_table.resolved_hour",
        :select_columns => "received_tickets;resolved_tickets" })
    source_tickets = helpdesk_analysis_query(conditions,
      {:group_by => "report_table.created_at, source", 
      :select_columns => "received_tickets"})
    data_hash.store('received_tickets',
      prepare_data_series(I18n.t('adv_reports.load.tickets_received'),'received_tickets',tickets_count,
        {:type => "line", :color => "#4a7ebb"}))
    data_hash.store('resolved_tickets',
      prepare_data_series(I18n.t('adv_reports.tickets_resolved'),'resolved_tickets',tickets_count,
        {:type => "line", :color => "#be4b48"}))
    data_hash.store('backlog_tickets',
      prepare_data_series(I18n.t('adv_reports.tickets_backlog'),'backlog_tickets',tickets_count,
        {:type => "line", :color => "#98b954"}))
    data_hash.store('tickets_by_source',
      prepare_source_data_series('received_tickets',source_tickets))
    data_hash.store('tickets_by_arrival',prepare_time_of_arrival_series(time_of_arrival_tkts))
    return data_hash
  end

  def performance_analysis_data(conditions)
    data_hash = {}
    tickets_count = helpdesk_analysis_query(conditions,{:group_by => "report_table.created_at" })
    #Response Accuracy
    data_hash.store('resolved_tickets',
      prepare_data_series(I18n.t('adv_reports.tickets_resolved'),'resolved_tickets',tickets_count,
        {:type => "line", :color => "#4a7ebb"}))
    data_hash.store('fcr_tickets',
      prepare_data_series(I18n.t('adv_reports.load.tickets_with_fcr'),'fcr_tickets',tickets_count,
        {:type => "line", :color => "#be4b48"}))
    data_hash.store('sla_tickets',
      prepare_data_series(I18n.t('adv_reports.load.tickets_within_SLA'),'sla_tickets',tickets_count,
        {:type => "line", :color => "#98b954"}))
    data_hash.store('num_of_reopens',
      prepare_data_series(I18n.t('adv_reports.load.tickets_reopened'),'num_of_reopens',tickets_count,
        {:type => "line", :color => "#80699b"}))
    #Response Time
    data_hash.store('first_response_time',
      prepare_data_series(I18n.t('adv_reports.comparison_reports.avg_first_resp_time'),'avgfirstresptime',tickets_count,
        {:type => "line", :color => "#4a7ebb"},true))
    data_hash.store('avg_response_time',
      prepare_data_series(I18n.t('adv_reports.comparison_reports.avg_resp_time'),'avgresponsetime',tickets_count,
        {:type => "line", :color => "#be4b48"}))

    #Interactions..
    data_hash.store('customer_interactions',
      prepare_data_series(I18n.t('adv_reports.glance.avg_cust_intr'),'avgcustomerinteractions',tickets_count,
        {:type => "line", :color => "#be4b48"}))  
    data_hash.store('agent_interactions',
      prepare_data_series(I18n.t('adv_reports.glance.avg_agent_intr'),'avgagentinteractions',tickets_count,
        {:type => "line", :color => "#4a7ebb"}))  

    #Ticket Assignments..
    data_hash.store('tickets_assigned',
      prepare_data_series(I18n.t('adv_reports.load.tkt_assignment'),'assigned_tickets',tickets_count,
        {:type => "line", :color => "#be4b48"}))  
    data_hash.store('num_of_reassigns',
      prepare_data_series(I18n.t('adv_reports.glance.num_of_reassigns'),'num_of_reassigns',tickets_count,
        {:type => "line", :color => "#4a7ebb"}))
    return data_hash
  end

  def prepare_data_series(name,col_name,data_array,options={},convertTimeToHrs = false)
    data_hash, series_data, dates_with_data = {}, [], {}
    data_hash.store(:name,name)
    data_array.each do |tkt|
      next if tkt['created_at'].nil?
      data_value = convertTimeToHrs ? ((tkt[col_name].to_f)/3600).round(2) : tkt[col_name].to_f.round(2)
      dates_with_data.store(Time.parse("#{tkt['created_at']}").to_i*1000, data_value)
    end
    # Pushing the dates with 0 tickets
    this_date, report_end_date = Time.parse(start_date(false)), Time.parse(end_date(false))
    until this_date >= (report_end_date.since 1.day)
      this_date_in_millies = this_date.to_i*1000
      if(dates_with_data.key?(this_date_in_millies))
        series_data.push([this_date_in_millies,dates_with_data.fetch(this_date_in_millies)])
      else
        series_data.push([this_date_in_millies,0])
      end
      this_date = this_date.since 1.day
    end
    data_hash.store(:data,series_data)
    data_hash.store(:type,options[:type])
    data_hash.store(:color,options[:color])
    data_hash
  end

  def prepare_source_data_series(col_name,data_array)
    data_hash = {'1'=>{:name=>I18n.t('email'),:type=>'line',:color=>'#98b954',:data=>[]},
                 '2'=>{:name=>I18n.t('portal_key'),:type=>'line',:color=>'#1E1ECA',:data=>[]},
                 '3'=>{:name=>I18n.t('phone'),:type=>'line',:color=>'#be4b48',:data=>[]},
                 '4'=>{:name=>I18n.t('forum_key'),:type=>'line',:color=>'#80699b',:data=>[]},
                 '5'=>{:name=>I18n.t('twitter_source'),:type=>'line',:color=>'#3ba4c1',:data=>[]},
                 '6'=>{:name=>I18n.t('facebook_source'),:type=>'line',:color=>'#225222',:data=>[]},
                 '7'=>{:name=>I18n.t('chat'),:type=>'line',:color=>'#8E7722',:data=>[]},
                 '8'=>{:name=>I18n.t('mobi_help'),:type=>'line',:color=>'#EEA222',:data=>[]}
                }

    dates_with_data = {}
    #Storing the dates having data
    data_array.each do |tkt|
      next if tkt['created_at'].nil?
      time_in_millis = Time.parse("#{tkt['created_at']}").to_i*1000
      dates_with_data[time_in_millis] ||= {}
      dates_with_data[time_in_millis][tkt['source']] = tkt[col_name].to_i
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

  def prepare_time_of_arrival_series(data_array)
    data_hash = {'received'=>{:name=>I18n.t('adv_reports.load.tickets_received'),:color=>'#dddddd',:data=>[]},
                 'resolved'=>{:name=>I18n.t('adv_reports.tickets_resolved'),:color=>'#277600',:data=>[]}}
    received_tickets_hash, resolved_tickets_hash = {},{}
    data_array.each do |row|
      if row['received_tickets'].to_i > 0 && !row['created_hour'].nil?
        received_tickets_hash[row['created_hour']] = received_tickets_hash.key?(row['created_hour']) ? 
         (received_tickets_hash[row['created_hour']] + row['received_tickets'].to_i) : row['received_tickets'].to_i
      end
      if row['resolved_tickets'].to_i > 0 && !row['resolved_hour'].nil?
        resolved_tickets_hash[row['resolved_hour']] = resolved_tickets_hash.key?(row['resolved_hour']) ? 
         (resolved_tickets_hash[row['resolved_hour']] + row['resolved_tickets'].to_i) : row['resolved_tickets'].to_i
      end 
    end
    for hr in 0..23
      data_hash["received"][:data].push(received_tickets_hash.key?(hr.to_s) ? received_tickets_hash[hr.to_s] : 0)
      data_hash["resolved"][:data].push(resolved_tickets_hash.key?(hr.to_s) ? resolved_tickets_hash[hr.to_s] : 0)
    end
    data_hash
  end

end