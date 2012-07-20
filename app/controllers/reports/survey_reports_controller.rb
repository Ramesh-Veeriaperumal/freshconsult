class Reports::SurveyReportsController < ApplicationController

	before_filter { |c| c.requires_feature :surveys }
	before_filter { |c| c.requires_permission :manage_reports }

	before_filter :set_selected_tab

	include Reports::SurveyReport

	LIST_LIMIT = 90

	def index

		if agent?
			agent_list
		elsif group?
			group_list
		else
			overall_summary			
			redirect_to survey_overall_report_path(overall_params) and return if (@reports_list.size > 0 && !(!params[:view].blank? && params[:view] == Survey::LIST ))
		end
    		
	end

	def list
		if agent?
			agent_list
		elsif group?
			group_list
		else
			overall_summary			
			redirect_to survey_overall_report_path(overall_params) and return if (@reports_list.size > 0 && !(!params[:view].blank? && params[:view] == Survey::LIST ))
		end

		render :partial => "list"	
	end

	def fetch_details
		if agent?

			agent_list

			remarks

		elsif group?

			group_list

			remarks

		else

			overall_summary

			remarks

		end
	end

	def report_details

		fetch_details

	end

	def refresh_details

		fetch_details

		render :partial => 'refresh_details'

	end

	def feedbacks

		remarks

		render :partial => 'feedbacks'

	end

	def conditional_params		

		condtions = ""
      		
      		count = 0

		      unless params[:entity_id].blank? || company?
		      	conditions = "survey_results.agent_id = #{params[:entity_id]}" if agent?
		      	conditions = "survey_results.group_id = #{params[:entity_id]}" if group?
		      	count+=1
		      end	

		      unless params[:rating].blank?
	     		rating_con = "survey_results.rating = #{params[:rating]}"
	      		(count>0) ? conditions += (" and " + rating_con) : conditions = rating_con
	      		count+=1
		      end


	      	      start_con = "survey_results.created_at between '#{start_date}' and '#{end_date}'"
	      	      (count>0) ? conditions += (" and " + start_con) : conditions = start_con



		return Array(conditions)
	end		

	protected	

            def set_selected_tab
  		@selected_tab = :reports
	end	

	def page_limit
		return 10
  	end

    def agent_list
      							      							      
      @survey_reports = current_account.survey_results.agent(conditional_params).paginate( :page => current_page, :per_page => LIST_LIMIT )      
      @reports_list = current_account.survey_results.generate_reports_list(@survey_reports,Survey::AGENT,sort_by)

    end

    def group_list
      
      @survey_reports = current_account.survey_results.group(conditional_params).paginate(:page => params[:page], :per_page => LIST_LIMIT)
      
      @reports_list = current_account.survey_results.generate_reports_list(@survey_reports,Survey::GROUP,sort_by)

    end

    def overall_summary
    	@survey_reports = current_account.survey_results.portal(conditional_params).paginate(:page => params[:page], :per_page => LIST_LIMIT)

    	@reports_list = current_account.survey_results.generate_reports_list(@survey_reports,Survey::OVERALL,sort_by)
    end

    def remarks
    	@remarks = current_account.survey_results.remarks(conditional_params).paginate(:page => params[:page], :per_page => page_limit)
    end

    private

    def agent?
    	(params[:category].blank? || params[:category] == Survey::AGENT)
    end

    def group?
    	(params[:category] == Survey::GROUP)
    end
  
    def company?
    	(params[:category] == Survey::OVERALL)
    end

    def overall_params
    	custom_params = Hash.new
	custom_params[:category] = Survey::OVERALL
	custom_params[:date_range] = params[:date_range] unless params[:date_range].blank?
	return custom_params
    end

    def current_page
    	params[:page] = 1 if params[:page].blank?

    	params[:page]
    end

    def sort_by
    	return :name if params[:sort].blank?
    	params[:sort]
    end
end