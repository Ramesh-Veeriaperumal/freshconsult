class Reports::SurveyReportsController < ApplicationController

	before_filter { |c| c.requires_feature :surveys }
	before_filter { |c| c.requires_permission :manage_reports }

	before_filter :set_selected_tab

	include Reports::SurveyReport

	def index

		if params[:category].blank? || params[:category] == "agent"
			agent_list
		elsif params[:category] == "group"
			group_list
		else
			report_details and return
		end

    		render :partial => 'list' unless (params[:category].blank? || params[:uitype]=="main")
    		
	end	

	def fetch_details
		if params[:category].blank? || params[:category] == "agent"

			agent_list

			agent_remarks

		elsif params[:category] == "group"

			group_list

			group_remarks			

		else

			overall_summary

			overall_remarks

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

		if params[:category].blank? || params[:category] == "agent"
			agent_remarks
		elsif params[:category] == "group"
			group_remarks
		else 
			overall_remarks
		end

		render :partial => 'feedbacks'

	end

	def conditional_params		

		condtions = ""
      		
      		count = 0

		      unless params[:entity_id].blank? 
		      	conditions = "survey_results.agent_id = #{params[:entity_id]}" if (params[:category] == "agent" || params[:category].blank?)
		      	conditions = "survey_results.group_id = #{params[:entity_id]}" if (params[:category] == "group")
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
      							      							      
      survey_reports = current_account.survey_results.find(:all,
							 :select => "users.id as id,users.name as name,survey_results.rating as rating,users.job_title as title,count(*) as total",
							 :joins => :agent, 
							 :group => "survey_results.agent_id,survey_results.rating",
							 :conditions => conditional_params).paginate(:page => params[:page], :per_page => page_limit)
      
      @reports_list = current_account.survey_results.generate_reports_list(survey_reports,"agent")

    end

    def group_list
      
      survey_reports = current_account.survey_results.find(:all,
								:select => "group_id as id,groups.name as name,survey_results.rating as rating,groups.description as title,count(*) as total",
								:joins => :group, 
								:group => "survey_results.group_id,survey_results.rating",
								:conditions => conditional_params).paginate(:page => params[:page], :per_page => page_limit)
      
      @reports_list = current_account.survey_results.generate_reports_list(survey_reports,"group")

    end

    def overall_summary
    	survey_reports = current_account.survey_results.find(:all,
    								:joins => [:account],    								
								:select => "account_id as id,accounts.name as name,survey_results.rating as rating,accounts.full_domain as title,count(*) as total",								
								:group => "survey_results.account_id,survey_results.rating",
								:conditions => conditional_params).paginate(:page => params[:page], :per_page => page_limit)
    	@reports_list = current_account.survey_results.generate_reports_list(survey_reports,"company")
    end

    def agent_remarks
    	
 	@remarks = current_account.survey_results.find(:all, 								
 							    :include => [:survey_remark],	
							   :conditions => conditional_params).paginate(:page => params[:page], :per_page => page_limit)
    end
    
    def group_remarks()
    	
 	
 	@remarks = current_account.survey_results.find(:all, 								
 							    :include => [:survey_remark],	
							   :conditions => conditional_params).paginate(:page => params[:page], :per_page => page_limit)
    end
    
    def overall_remarks()
    	
 	@remarks = current_account.survey_results.find(:all, 								
 							    :include => [:survey_remark],	
							   :conditions => conditional_params).paginate(:page => params[:page], :per_page => page_limit)
    end
end