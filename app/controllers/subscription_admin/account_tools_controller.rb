class SubscriptionAdmin::AccountToolsController < ApplicationController
	include ModelControllerMethods
  include AdminControllerMethods
  include Redis::RedisKeys
	include Redis::ReportsRedis

  before_filter :set_selected_tab  

  def index
  end

  def regenerate_reports_data
  	# return if params[:account_id].nil? || params[:start_date].nil? || params[:end_date].nil?
		
		(params[:start_date].to_date).upto(params[:end_date].to_date) do |day|
			add_to_reports_set(REPORT_STATS_REGENERATE_KEY % {:account_id => params[:account_id]}, day)
		end

    respond_to do |format|
      format.json { render :json => 'success' }
    end
  end
  protected
    def set_selected_tab
       @selected_tab = :tools
    end   
end