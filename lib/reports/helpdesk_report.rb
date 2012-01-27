module Reports::HelpdeskReport
   
  include Reports::ChartGenerator
  include Reports::ActivityReport
   
  def columns
   [:status,:ticket_type,:priority,:source] 
  end
   
  def pie_chart_columns
    [:ticket_type,:priority]
  end
  
  def timeline_columns
   [:created_at,:resolved_at] 
  end
 
  def calculate_resolved_on_time
     resolved_count = count_of_resolved_on_time
     if !@current_month_tot_tickets.nil? and !@current_month_tot_tickets != 0
       @avg_sla_current_month = (resolved_count.to_f/@current_month_tot_tickets.to_f) * 100
     end
     last_month_resolved_count = last_month_count_of_resolved_on_time
     last_month_tot_tickets = count_of_tickets_last_month
     if !last_month_tot_tickets.nil? and last_month_tot_tickets != 0
       avg_sla_last_month = (last_month_resolved_count.to_f/last_month_tot_tickets.to_f) * 100
     end
     if !avg_sla_last_month.nil? and !@avg_sla_current_month.nil?
       @sla_diff = @avg_sla_current_month - avg_sla_last_month
     end

     gen_pie_gauge(@avg_sla_current_month,"sla")
  end
  
  def calculate_fcr
     fcr_count = count_of_fcr
     if !@current_month_tot_tickets.nil? and @current_month_tot_tickets != 0
       @avg_fcr_month = (fcr_count.to_f/@current_month_tot_tickets.to_f) * 100
     end
     last_month_fcr_count = last_month_count_of_fcr
     last_month_tot_tickets = count_of_tickets_last_month
     if !last_month_tot_tickets.nil? and last_month_tot_tickets != 0
       avg_last_month = (last_month_fcr_count.to_f/last_month_tot_tickets.to_f) * 100
     end
     if !avg_last_month.nil? and !@avg_fcr_month.nil?
       @fcr_diff = @avg_fcr_month - avg_last_month
     end
     gen_pie_gauge(@avg_fcr_month,"fcr")
  end
   
  def get_tickets_time_line(params)
    timeline_columns.each do |column|
      ticket_timeline = group_tkts_by_timeline(column)
      self.instance_variable_set("@#{column}_hash", ticket_timeline)
    end
    gen_line_chart(@created_at_hash,@resolved_at_hash)
  end
   
    
  def get_tickets_hash(tickets_count,column_name,chart_type = :pie)
    tot_count = 0
    tickets_hash = {}
    tickets_count.each do |ticket|
      tot_count += ticket.count.to_i
      if column_name.to_s.starts_with?('flexifields.')
        tickets_hash.store(ticket.send(column_name.gsub('flexifields.','')),{:count => ticket.count})
      else
        tickets_hash.store(ticket.send(column_name),{:count => ticket.count})
      end

    end
    tickets_hash.store(TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved], add_resolved_and_closed_tickets(tickets_hash)) if column_name == 'status'
    @current_month_tot_tickets = tot_count
    tickets_hash = calculate_percentage_for_columns(tickets_hash,@current_month_tot_tickets)
    
    case chart_type
      when :stacked_bar_single
        gen_single_stacked_bar_chart(tickets_hash, column_name)
      else
        gen_pie_chart(tickets_hash,column_name)
    end
    
    tickets_hash
  end
   
  def post_processing(processed_hash,column_name)
     
  end
   
  def group_tkts_by_columns(params,vals={})
    scoper.find( 
     :all,
     :joins => [:requester, :flexifield],
     :select => "count(*) count, #{vals[:column_name]}",
     :conditions => ["#{vals[:column_name]} is NOT NULL"],
     :order => "count(*) DESC",
     :group => "#{vals[:column_name]}")
  end
  
  def timeline_date_condition(startDate = nil, endDate = nil)
    ending_time ||= @ending_date
    starting_time ||= @starting_date
    " helpdesk_ticket_states.created_at >= '#{starting_time.to_s(:db)}' and helpdesk_ticket_states.created_at <= '#{ending_time.to_s(:db)}' and  helpdesk_ticket_states.resolved_at >= '#{starting_time.to_s(:db)}' and helpdesk_ticket_states.resolved_at <= '#{ending_time.to_s(:db)}' "
  end
   
  def group_tkts_by_timeline(type,startingDate=nil, endingDate=nil)
    Account.current.tickets.find( 
     :all,
     :select => "count(*) count,helpdesk_ticket_states.#{type} date",
     :joins => :ticket_states,
     :conditions => fetch_condition(type,startingDate, endingDate),
     :group => "DATE(helpdesk_ticket_states.#{type})")
  end
   
  def fetch_condition(type,startingDate=nil, endingDate=nil)
    condition = timeline_date_condition(startingDate, endingDate)
    condition = "#{condition} and resolved_at IS NOT NULL" if type.to_s.eql?("resolved_at")
    return condition 
  end
  
  def count_of_tickets_last_month
    @last_month_tot_tickets ||= scoper(@prev_starting, @prev_ending).count 
  end
  
  def count_of_fcr
    scoper.first_call_resolution.count
  end
   
  def last_month_count_of_fcr
    scoper(@prev_starting, @prev_ending).first_call_resolution.count
  end
  
   
  def count_of_resolved_on_time
    scoper.resolved_and_closed_tickets.resolved_on_time.count
  end
   
  def last_month_count_of_resolved_on_time
    scoper(@prev_starting, @prev_ending).resolved_and_closed_tickets.resolved_on_time.count
  end
    
end