module Reports::CompanyReport
  
  include Reports::ChartGenerator
  include Reports::ActivityReport
  
  def columns
   [:status,:source] 
  end
   
  def pie_chart_columns
    [:ticket_type,:priority]
  end
  
  def timeline_columns
   [:created_at,:resolved_at] 
 end

  def fetch_condition(type)
    condition = timeline_date_condition(type)
    condition = "#{condition} AND users.customer_id = '#{params[:customer_id]}'"
    condition = "#{condition} and resolved_at IS NOT NULL" if type.to_s.eql?("resolved_at")
    return condition
  end

  def count_of_tickets_last_month()
   @last_month_tot_tickets = scoper(previous_start,previous_end).find(
     :all,
     :joins => :requester,
     :conditions => { :users => {:customer_id => "#{params[:customer_id]}"}}).count
  end

  def count_of_resolved_tickets
    @count_of_resolved_tickets ||= Account.current.tickets.visible.find( 
     :all,
     :joins => [:requester, :ticket_states],
     :conditions => ["(`users`.`customer_id` = ?) AND (helpdesk_ticket_states.resolved_at > '#{start_date}' and helpdesk_ticket_states.resolved_at < '#{end_date}' )",params[:customer_id] ]).count
  end

  def group_tkts_by_columns(vals={})
    scoper.find(
     :all,
     :joins => [:requester, :flexifield],
     :select => "count(*) count, #{vals[:column_name]}",
     :conditions => [" users.customer_id = ? and #{vals[:column_name]} is NOT NULL",params[:customer_id]],
     :group => "#{vals[:column_name]}")
  end
  
  def group_tkts_by_timeline(type)
    Account.current.tickets.visible.find(
     :all,
     :select => "count(*) count,DATE(helpdesk_ticket_states.#{type}) date",
     :joins => [:ticket_states, :requester],
     :conditions => fetch_condition(type),
     :group => "DATE(helpdesk_ticket_states.#{type})")
  end

  def count_of_fcr
    scoper.company_first_call_resolution(params[:customer_id]).count
  end
   
  def last_month_count_of_fcr
    scoper(previous_start, previous_end).company_first_call_resolution(params[:customer_id]).count
  end
  
  def count_of_resolved_on_time
    scoper.resolved_and_closed_tickets.company_tickets_resolved_on_time(params[:customer_id]).count
  end
  
  def last_month_count_of_resolved_on_time
    scoper(previous_start,previous_end).resolved_and_closed_tickets.company_tickets_resolved_on_time(params[:customer_id]).count
  end

end