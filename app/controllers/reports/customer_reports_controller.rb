class Reports::CustomerReportsController < ApplicationController
  include Reports::CompanyReport
  
  before_filter { |c| c.requires_permission :manage_tickets }
  
  
  def index
    unless params[:customer_id].blank?
      count_of_tickets_last_month
      company_activity(params)
      calculate_resolved_on_time(params)
      @customer_tickets = customer_tickets
    end
  end
  
  def customer_tickets
    scoper(params[:date][:month]).visible.all_company_tickets(params[:customer_id]).newest(5)
  end
  
 
  
end