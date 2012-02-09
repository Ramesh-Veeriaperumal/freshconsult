module Reports::HelpdeskReport
   
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

 def group_tkts_by_columns(vals={})
    scoper.find( 
     :all,
     :joins => :flexifield,
     :select => "count(*) count, #{vals[:column_name]}",
     :conditions => ["#{vals[:column_name]} is NOT NULL"],
     :group => "#{vals[:column_name]}")
  end
  
  def group_tkts_by_timeline(type,startingDate=nil, endingDate=nil)
    Account.current.tickets.visible.find( 
     :all,
     :select => "count(*) count,DATE(helpdesk_ticket_states.#{type}) date",
     :joins => :ticket_states,
     :conditions => fetch_condition(type),
     :group => "DATE(helpdesk_ticket_states.#{type})")
  end
   
  def fetch_condition(type)
    condition = timeline_date_condition(type)
    condition = "#{condition} and resolved_at IS NOT NULL" if type.to_s.eql?("resolved_at")
    return condition 
  end
  
  def count_of_tickets_last_month
    @last_month_tot_tickets ||= scoper(previous_start, previous_end).count 
  end
  
  def count_of_fcr
    scoper.first_call_resolution.count
  end
   
  def last_month_count_of_fcr
    scoper(previous_start, previous_end).first_call_resolution.count
  end
  
   
  def count_of_resolved_on_time
    scoper.resolved_and_closed_tickets.resolved_on_time.count
  end
   
  def last_month_count_of_resolved_on_time
    scoper(previous_start, previous_end).resolved_and_closed_tickets.resolved_on_time.count
  end
    
end