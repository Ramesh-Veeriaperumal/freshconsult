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

  	@date_range = "#{7.days.ago.strftime("%d %B %Y")} - #{0.days.ago.strftime("%d %B %Y")}"
	@agents_list = Hash[current_account.agents_from_cache.map { |c| [c.user.id,c.user.name] }].to_json.html_safe
	@widget_ids = current_account.chat_widgets.collect{ |c| [c.name, c.widget_id] }.unshift([t('reports.freshchat.all'), "all"])
	@main_widget = current_account.chat_widgets.find(:first, :conditions => {:main_widget => true}).widget_id
  end

  private 

    def set_selected_tab
      @selected_tab = :reports
    end

end