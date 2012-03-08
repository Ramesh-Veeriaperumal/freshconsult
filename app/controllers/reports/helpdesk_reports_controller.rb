class Reports::HelpdeskReportsController < ApplicationController
  
  include Reports::HelpdeskReport
  
  before_filter { |c| c.requires_feature :advanced_reporting }
  before_filter { |c| c.requires_permission :manage_reports }
  before_filter :set_selected_tab
  before_filter :set_default_values
  
  def generate
    @pie_charts_hash = {}
    fetch_activity
    calculate_resolved_on_time
    calculate_fcr
    get_tickets_time_line
    render :partial => "/reports/shared/report"
  end
  
   def export_to_excel
     @pie_charts_hash = {}
     fetch_activity
     get_tickets_time_line
     send_data write_io, :filename => 'helpdesk_report.xls',
        :type => 'application/vnd.ms-excel; charset=utf-8; header=present', 
            :disposition => "attachment; filename=helpdesk_report.xls" 
   end
  
  
  
 protected
  
  def set_selected_tab
      @selected_tab = :reports
  end
  
  def set_default_values
    @show_fields = { :priority =>  t('ticket_fields.fields.priority'),
                     :ticket_type => t('ticket_fields.fields.ticket_type')
                    }
    @pie_chart_labels = {"priority" => t('ticket_fields.fields.priority'), "ticket_type" => t('ticket_fields.fields.ticket_type')}
    current_account.ticket_fields.custom_dropdown_fields.each do |f|
      @show_fields[ "flexifields.#{f.flexifield_def_entry.flexifield_name}"] = f.label
      @pie_chart_labels.store "flexifields.#{f.flexifield_def_entry.flexifield_name}" , f.label
    end
  end
  
end