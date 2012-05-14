class Reports::SurveyReportsController < ApplicationController
	
	include Reports::SurveyReport
	
	def index
				
		if params[:category].blank? || params[:category] == "agent"
			@reports_list = SurveyResult.fetch_agent_report(current_account.id,conditional_params)
		elsif params[:category] == "group"
			@reports_list = SurveyResult.fetch_group_report(current_account.id,conditional_params)
			puts "GROUP REPORTS LIST >>>> #{@reports_list.to_yaml}"
		else
			@reports_list = SurveyResult.fetch_company_report(current_account.id,conditional_params)
		end		
    	
    	render :partial => 'list' unless params[:category].blank?
    		
	end
	
	def report_details
		if params[:category].blank? || params[:category] == "agent"
			@summary = SurveyResult.fetch_agent_report(current_account.id,conditional_params)
			@remarks = SurveyResult.fetch_agent_report_details(current_account.id,conditional_params)
		elsif params[:category] == "group"
			@summary = SurveyResult.fetch_group_report(current_account.id,conditional_params)
			@remarks = SurveyResult.fetch_group_report_details(current_account.id,conditional_params)
		else
			@summary = SurveyResult.fetch_company_report(current_account.id,conditional_params)
			@remarks = SurveyResult.fetch_company_report_details(current_account.id,conditional_params)
		end				
		
		render :partial => 'report_details'
		
	end
	
	def conditional_params
		condition = {}
		condition[:entity_id]=params[:entity_id] unless params[:entity_id].blank?
		condition[:rating]=params[:rating] unless params[:rating].blank?
		condition[:category]=params[:category] unless params[:category].blank?
		condition[:start_date] = start_date
		condition[:end_date] = end_date
		return condition
	end		
  
end