class Reports::Freshchat::SummaryReportsController < ApplicationController

  before_filter :set_selected_tab

  def index
	#Render default index erb
	@table_headers =  { 
		:agent_name => t('reports.freshchat.agent'),
		:answered_chats => t('reports.freshchat.answered_chats'),
		:avg_handle_time => t('reports.freshchat.avg_handle_time'),
		:total_duration => t('reports.freshchat.total_duration')
	}
  @report_type = "chat_summary"
  @date_range = "#{7.days.ago.strftime("%d %b %Y")} - #{0.days.ago.strftime("%d %b %Y")}"
	@agents_list = Hash[current_account.agents_from_cache.map { |c| [c.user.id,c.user.name] }].to_json.html_safe
	@widget_ids = current_account.chat_widgets.reject{|c| c.widget_id ==nil}.collect{ |c| [c.name, c.widget_id] }.unshift([t('reports.freshchat.deleted'), "deleted"]).unshift([t('reports.freshchat.all'), "all"])
	@main_widget = current_account.chat_widgets.find(:first, :conditions => {:main_widget => true}).widget_id
	@chat_types = [[t('reports.freshchat.all'), "0"], [t('reports.freshchat.chat_type_visitor'), "1"], [t('reports.freshchat.chat_type_agent'), "2"], [t('reports.freshchat.chat_type_proactive'), "3"]]
  end

  private 

    def set_selected_tab
      @selected_tab = :reports
    end

end