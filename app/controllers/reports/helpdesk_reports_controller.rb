class Reports::HelpdeskReportsController < ApplicationController
  include Reports::HelpdeskReport

  before_filter :set_default_values
  before_filter { |c| c.requires_permission :manage_tickets }
  
  
  def index
    @selected_tab = :reports
  end

  def generate
    #By default, Priority & Source options are selected
    params[:reports] ||= ['priority','ticket_type']
    Time::DATE_FORMATS[:reports] = "%d %B %Y"
    now = Time.now
    params[:dateRange] ||= "#{(now - 31.days).to_time.to_s(:reports)} - #{(now - 1.day).to_time.to_s(:reports)}"
 
    calc_times(params)
    fetch_activity(params)
    calculate_resolved_on_time
    calculate_fcr
    get_tickets_time_line(params)
    @line_data = gen_line_chart_data(@all_hash,@resolved_hash)

    render :partial => "/reports/shared/canvas"
  end


  def set_default_values
    fields = [[:priority, t('ticket_fields.fields.priority')], [:ticket_type,t('ticket_fields.fields.ticket_type')]]
    @pie_chart_labels = {"priority" => t('ticket_fields.fields.priority'), "ticket_type" => t('ticket_fields.fields.ticket_type')}
    current_account.ticket_fields.custom_dropdown_fields.each do |f|
      fields.push [ "flexifields.#{f.flexifield_def_entry.flexifield_name}", f.label]
      @pie_chart_labels.store "flexifields.#{f.flexifield_def_entry.flexifield_name}" , f.label
    end
    @show_options = [
      {
        :label => t("reports.select_options"), 
        :value=>['priority','ticket_type'], 
        :name=>"reports", 
        :options=>fields, 
        :container=>:dropdown
      }
    ]
  end

end