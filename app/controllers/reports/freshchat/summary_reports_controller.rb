class Reports::Freshchat::SummaryReportsController < ApplicationController

  include HelpdeskReports::Helper::ControllerMethods
  include HelpdeskReports::Helper::ScheduledReports
  
  before_filter :set_selected_tab, :set_report_type
  before_filter :report_filter_data_hash,                  :only => [:index]
  before_filter :save_report_max_limit?,                   :only => [:save_reports_filter]
  before_filter :construct_report_filters,                 :only => [:save_reports_filter,:update_reports_filter]

  helper_method :enable_schedule_report?

  attr_accessor :report_type

  def index
  #Render default index erb
    @table_headers = get_chat_table_headers
    @date_range = "#{7.days.ago.strftime("%d %b %Y")} - #{0.days.ago.strftime("%d %b %Y")}"
    @agents_list = Hash[current_account.agents_from_cache.map { |c| [c.user.id,c.user.name] }].to_json.html_safe
    @widget_ids = current_account.chat_widgets.reject{|c| c.widget_id ==nil}.collect{ |c| [c.name, c.widget_id] }.unshift([t('reports.freshchat.deleted'), "deleted"]).unshift([t('reports.freshchat.all'), "all"])
    @main_widget = current_account.chat_widgets.find(:first, :conditions => {:main_widget => true}).widget_id
    @chat_types = [[t('reports.freshchat.all'), "0"], [t('reports.freshchat.chat_type_visitor'), "1"], [t('reports.freshchat.chat_type_agent'), "2"], [t('reports.freshchat.chat_type_proactive'), "3"]]
  end

  def export_pdf   
    params.merge!(:report_type   => report_type)    
    Reports::Export.perform_async(params)   
    render json: nil, status: :ok   
  end

  def save_reports_filter
    common_save_reports_filter    
  end

  def update_reports_filter
    common_update_reports_filter
  end

  def delete_reports_filter
    common_delete_reports_filter
  end

  private 

    def set_selected_tab
      @selected_tab = :reports
    end

    def set_report_type
      @report_type         = :chat_summary
      @user_time_zone_abbr = Time.zone.now.zone
    end

end