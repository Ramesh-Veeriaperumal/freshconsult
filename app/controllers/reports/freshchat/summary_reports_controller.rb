class Reports::Freshchat::SummaryReportsController < ApplicationController

  include Reports::CommonHelperMethods
  
  before_filter :set_selected_tab, :set_report_type
  before_filter :report_filter_data_hash,  :only => [:index]
  before_filter :max_limit?, :only => [:save_reports_filter]
  before_filter :construct_filters,        :only => [:save_reports_filter,:update_reports_filter]

  attr_accessor :report_type

  def index
	#Render default index erb
		@table_headers =  { 
			:agent_name => t('reports.freshchat.agent'),
			:answered_chats => t('reports.freshchat.answered_chats'),
			:avg_handle_time => t('reports.freshchat.avg_handle_time'),
			:total_duration => t('reports.freshchat.total_duration')
		}

    @date_range = "#{7.days.ago.strftime("%d %b %Y")} - #{0.days.ago.strftime("%d %b %Y")}"
		@agents_list = Hash[current_account.agents_from_cache.map { |c| [c.user.id,c.user.name] }].to_json.html_safe
		@widget_ids = current_account.chat_widgets.reject{|c| c.widget_id ==nil}.collect{ |c| [c.name, c.widget_id] }.unshift([t('reports.freshchat.deleted'), "deleted"]).unshift([t('reports.freshchat.all'), "all"])
		@main_widget = current_account.chat_widgets.find(:first, :conditions => {:main_widget => true}).widget_id
		@chat_types = [[t('reports.freshchat.all'), "0"], [t('reports.freshchat.chat_type_visitor'), "1"], [t('reports.freshchat.chat_type_agent'), "2"], [t('reports.freshchat.chat_type_proactive'), "3"]]
  end

   def save_reports_filter
    report_filter = current_user.report_filters.build(
      :report_type => @report_type_id,
      :filter_name => @filter_name,
      :data_hash   => @data_map
    )
    report_filter.save
    
    render :json => {:text=> "success", 
                     :status=> "ok",
                     :id => report_filter.id,
                     :filter_name=> @filter_name,
                     :data=> @data_map }.to_json
  end

  def update_reports_filter
    id = params[:id].to_i
    report_filter = current_user.report_filters.find(id)
    report_filter.update_attributes(
      :report_type => @report_type_id,
      :filter_name => @filter_name,
      :data_hash   => @data_map
    )
    render :json => {:text=> "success", 
                     :status=> "ok",
                     :id => report_filter.id,
                     :filter_name=> @filter_name,
                     :data=> @data_map }.to_json
  end

  def delete_reports_filter
    id = params[:id].to_i
    report_filter = current_user.report_filters.find(id)
    report_filter.destroy 
    render json: "success", status: :ok
  end

  private 

    def set_selected_tab
      @selected_tab = :reports
    end

    def set_report_type
    	@report_type = "chat_summary"
    end

end