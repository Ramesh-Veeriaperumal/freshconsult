class Reports::SurveyReportsController < ApplicationController
	
	before_filter { |c| c.requires_feature :surveys }
	before_filter { |c| c.requires_permission :manage_reports }
	before_filter :set_selected_tab
			
	include Reports::SurveyReport
	
	def index
				
		if params[:category].blank? || params[:category] == "agent"
			@reports_list = current_account.survey_results.fetch_agent_report(current_account.id,conditional_params)			
		elsif params[:category] == "group"
			@reports_list = current_account.survey_results.fetch_group_report(current_account.id,conditional_params)			
		else			
			report_details and return			
		end
    	
    	render :partial => 'list' unless params[:category].blank?
    		
	end
	
	def report_details
		if params[:category].blank? || params[:category] == "agent"
			@summary = current_account.survey_results.fetch_agent_report(current_account.id,conditional_params)
			@remarks = current_account.survey_results.fetch_agent_report_details(current_account.id,conditional_params)
		elsif params[:category] == "group"
			@summary = current_account.survey_results.fetch_group_report(current_account.id,conditional_params)
			@remarks = current_account.survey_results.fetch_group_report_details(current_account.id,conditional_params)
		else
			@summary = current_account.survey_results.fetch_company_report(current_account.id,conditional_params)
			@remarks = current_account.survey_results.fetch_company_report_details(current_account.id,conditional_params)
		end				
		
		render :partial => 'report_details'
		
	end
	
	def feedbacks
		
		if params[:category].blank? || params[:category] == "agent"			
			@remarks = current_account.survey_results.fetch_agent_report_details(current_account.id,conditional_params)
		elsif params[:category] == "group"
			@remarks = current_account.survey_results.fetch_group_report_details(current_account.id,conditional_params)
		else 
			@remarks = current_account.survey_results.fetch_company_report_details(current_account.id,conditional_params)
		end
		
		render :partial => 'feedbacks'
		
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
	
	protected
	
	def set_selected_tab
      @selected_tab = :reports
  	end
  
end