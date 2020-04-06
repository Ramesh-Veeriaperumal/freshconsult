class Reports::Freshchat::SummaryReportsController < ApplicationController

  include HelpdeskReports::Helper::ControllerMethods
  include HelpdeskReports::Helper::ScheduledReports
  
  before_filter :set_selected_tab, :set_report_type
  before_filter :report_filter_data_hash,                         :only => [:index]
  before_filter :save_report_max_limit?,                          :only => [:save_reports_filter]
  before_filter :construct_report_filters, :schedule_allowed?,    :only => [:save_reports_filter,:update_reports_filter]

  helper_method :enable_schedule_report?

  attr_accessor :report_type

  def index
    #Render default index erb
    @table_headers =  { 
      :agent_name => t('reports.livechat.agent'),
      :answered_chats => t('reports.livechat.answered_chats'),
      :avg_handle_time => t('reports.livechat.avg_handle_time'),
      :total_duration => t('reports.livechat.total_duration')
    }

    @date_range = "#{7.days.ago.strftime("%d %b %Y")} - #{0.days.ago.strftime("%d %b %Y")}"
    @agents_list = Hash[current_account.agents_from_cache.map { |c| [c.user.id,c.user.name] }].to_json.html_safe
    @widget_ids = current_account.chat_widgets.reject{|c| c.widget_id ==nil}.collect{ |c| [c.name, c.widget_id] }.unshift([t('reports.livechat.deleted'), "deleted"]).unshift([t('reports.livechat.all'), "all"])
    @main_widget = current_account.chat_widgets.where(main_widget: true).first.widget_id
    @chat_types = [[t('reports.livechat.all'), "0"], [t('reports.livechat.chat_type_visitor'), "1"], [t('reports.livechat.chat_type_agent'), "2"], [t('reports.livechat.chat_type_proactive'), "3"]]
  end

  def export_pdf   
    params.merge!(:report_type   => report_type)    
    params.merge!(:portal_name => current_portal.name) if current_portal  
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

    def schedule_allowed?
      if params['data_hash']['schedule_config']['enabled'] == true 
        allow = enable_schedule_report? && current_user.privilege?(:export_reports)
        render json: nil, status: :ok if allow != true
      end
    end

    def set_selected_tab
      @selected_tab = :reports
    end

    def set_report_type
      @report_type         = :chat_summary
      @user_time_zone_abbr = Time.zone.now.zone
    end

end