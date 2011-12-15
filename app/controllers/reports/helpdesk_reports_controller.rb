class Reports::HelpdeskReportsController < ApplicationController
  include Reports::HelpdeskReport
  
  before_filter { |c| c.requires_permission :manage_tickets }
  
  
  def index
   unless params[:date].nil?
    fetch_activity(params)
    calculate_resolved_on_time(params)
    calculate_fcr(params)
    get_tickets_time_line(params)
    @line_data = gen_line_chart_data(@all_hash,@resolved_hash)
   end
 end
 
 
  
end