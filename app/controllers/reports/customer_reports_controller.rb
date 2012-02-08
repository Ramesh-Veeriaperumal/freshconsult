class Reports::CustomerReportsController < ApplicationController
  include Reports::CompanyReport
   
  before_filter { |c| c.requires_permission :manage_reports }
  before_filter :set_selected_tab
  before_filter :set_default_values
  before_filter :select_customer, :only => :generate

  def generate
    @pie_charts_hash = {}
    unless params[:customer_id].nil?  
     fetch_activity
     calculate_resolved_on_time
     get_tickets_time_line
     calculate_fcr
   end
    render :partial => "/reports/shared/canvas"
  end
  
  protected

  def set_selected_tab
   @selected_tab = :reports
  end
  
  def set_default_values
    @show_fields = { :priority =>  t('ticket_fields.fields.priority'),
                     :ticket_type => t('ticket_fields.fields.ticket_type') }
    @pie_chart_labels = {"priority" => t('ticket_fields.fields.priority'), "ticket_type" => t('ticket_fields.fields.ticket_type')}
    current_account.ticket_fields.custom_dropdown_fields.each do |f|
      @show_fields[ "flexifields.#{f.flexifield_def_entry.flexifield_name}"] = f.label
      @pie_chart_labels.store "flexifields.#{f.flexifield_def_entry.flexifield_name}" , f.label
    end
  end
  
  def select_customer
    if params[:customer_id].nil?
      @selected_customer = current_account.customers.first
      params[:customer_id] = @selected_customer.id if @selected_customer
    else
      @selected_customer = current_account.customers.find(params[:customer_id])
    end
  end

end