module Reports::CompanyReport
  
  include Reports::ChartGenerator
  include Reports::ActivityReport
  
  def columns
    [:status,:ticket_type,:priority]
  end
  
  def pie_chart_columns
    [:ticket_type,:priority]
  end

  def timeline_columns
   [:created_at,:resolved_at]
  end

  def fetch_condition(type,params)
    condition = timeline_date_condition(params)
    condition = "#{condition} AND users.customer_id = '#{params[:customer_id]}'"
    condition = "#{condition} and resolved_at IS NOT NULL" if type.to_s.eql?("resolved_at")
    return condition
  end


  def timeline_date_condition(params)
    " (helpdesk_ticket_states.created_at > '#{@starting_date.to_s(:db)}' and helpdesk_ticket_states.created_at < '#{@ending_date.to_s(:db)}' AND  helpdesk_ticket_states.resolved_at > '#{@starting_date.to_s(:db)}' and helpdesk_ticket_states.resolved_at < '#{@ending_date.to_s(:db)}' )"
      # " helpdesk_ticket_states.created_at > '#{@starting_date.to_s(:db)}' and helpdesk_ticket_states.created_at < '#{@ending_date.to_s(:db)}'"
  end

  
  def calculate_resolved_on_time(params)
     resolved_count = count_of_resolved_on_time()
     if !@current_month_tot_tickets.nil? and @current_month_tot_tickets != 0
       @avg_sla_current_month = (resolved_count.to_f/@current_month_tot_tickets.to_f) * 100
     end
     
     count_of_tickets_last_month
     last_month_resolved_count = last_month_count_of_resolved_on_time()
     if !@last_month_tot_tickets.nil? and @last_month_tot_tickets != 0
       avg_last_month = (last_month_resolved_count.to_f/@last_month_tot_tickets.to_f) * 100
     end
     
     @sla_diff = 0
     if !avg_last_month.nil? and !@avg_sla_current_month.nil?
       @sla_diff = @avg_sla_current_month - avg_last_month
     end
    
     gen_pie_gauge(@avg_sla_current_month,"sla") if !@current_month_tot_tickets.nil? and @current_month_tot_tickets != 0
     
  end
  
  def count_of_tickets_last_month()
   @last_month_tot_tickets = scoper(@prev_starting , @prev_ending).find(
     :all,
     :joins => :requester,
     :conditions => { :users => {:customer_id => "#{params[:customer_id]}"}}).count
  end
  
  def count_of_resolved_on_time()
    scoper().resolved_and_closed_tickets.company_tickets_resolved_on_time(params[:customer_id]).count
  end
  
  def last_month_count_of_resolved_on_time()
    scoper(@prev_starting.to_s(:db) , @prev_ending.to_s(:db)).resolved_and_closed_tickets.company_tickets_resolved_on_time(params[:customer_id]).count
  end

  def get_tickets_time_line(params)
    timeline_columns.each do |column|
      ticket_timeline = group_tkts_by_timeline(params,column)
      self.instance_variable_set("@#{column}_hash", ticket_timeline)
    end
    gen_line_chart(@created_at_hash,@resolved_at_hash)

    # Force to generate
  end

  def get_tickets_hash(tickets_count,column_name, chart_type = :pie)
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
    tickets_hash.store(TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved], {:count => add_resolved_and_closed_tickets(tickets_hash)}) if column_name.to_s == 'status'
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
  
  def group_tkts_by_columns(params,vals={})
    scoper.find(
     :all,
     :joins => [:requester, :flexifield],
     :select => "count(*) count, #{vals[:column_name]}",
     #:conditions => { :users => {:customer_id => "#{params[:customer_id]}"}, :flexifield => { vals[:column_name] => "IS NOT NULL" }},
     :conditions => [" users.customer_id = ? and #{vals[:column_name]} is NOT NULL",params[:customer_id]],
     :order => "count(*) DESC",
     :group => "#{vals[:column_name]}")
  end
  
  def group_tkts_by_timeline(params,type)
    Account.current.tickets.visible.find(
     :all,
     :select => "count(*) count,helpdesk_ticket_states.#{type} date",
     :joins => [:ticket_states, :requester],
     :conditions => fetch_condition(type,params),
     :group => "DATE(helpdesk_ticket_states.#{type})")
  end

  
  def scoper(starting_time = nil, ending_time = nil)
    ending_time ||= @ending_date
    starting_time ||= @starting_date
    Account.current.tickets.visible.created_at_inside(starting_time.to_time.to_s(:db),ending_time.to_time.to_s(:db))
  end


  def calculate_fcr(params)
     fcr_count = count_of_fcr(params)
     if !@current_month_tot_tickets.nil? and @current_month_tot_tickets != 0
       @avg_fcr_month = (fcr_count.to_f/@current_month_tot_tickets.to_f) * 100
     end
     last_month_fcr_count = last_month_count_of_fcr(params)
     last_month_tot_tickets = count_of_tickets_last_month
     if !last_month_tot_tickets.nil? and last_month_tot_tickets != 0
       avg_last_month = (last_month_fcr_count.to_f/last_month_tot_tickets.to_f) * 100
     end
     @fcr_diff = 0
     if !avg_last_month.nil? and !@avg_fcr_month.nil?
       @fcr_diff = @avg_fcr_month - avg_last_month
     end

     gen_pie_gauge(@avg_fcr_month,"fcr") if !@current_month_tot_tickets.nil? and @current_month_tot_tickets != 0
  end
   
  def count_of_fcr(params)
    scoper.company_first_call_resolution(params[:customer_id]).count
  end
   
  def last_month_count_of_fcr(params)
    scoper(@prev_starting, @prev_ending).company_first_call_resolution(params[:customer_id]).count
  end
  
end