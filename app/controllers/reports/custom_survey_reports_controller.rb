class Reports::CustomSurveyReportsController < ApplicationController

  before_filter { |c| current_account.new_survey_enabled? }

  before_filter :set_selected_tab, :only => :index

  include ReadsToSlave
  include Reports::CustomSurveyReport
  include ApplicationHelper
  
  AGENT_ALL_URL_REF = 'a'
  GROUP_ALL_URL_REF = 'g'
  RATING_ALL_URL_REF = 'r'

  def index
    @surveys = surveys_json
    @report_type = 'satisfaction_survey'
    @agents = agents
    @groups = groups
    @default_all_values = {:agent => AGENT_ALL_URL_REF, :group => GROUP_ALL_URL_REF, :rating => RATING_ALL_URL_REF}
  end

  def aggregate_report
    render :json => {:aggregate_report => aggregate_report_data}
  end

  def group_wise_report
    render :json => {:table_format_data => group_wise_report_data}
  end

  def agent_wise_report
    render :json => {:table_format_data => agent_wise_report_data}
  end
  
  def remarks
    remarks = survey.survey_results.remarks(default_params)
    question_column_name = survey_question.column_name
    remarks = filter remarks, question_column_name
    remarks = remarks.paginate(:page => current_page, :per_page => page_limit)
    result_json = remarks.remarks_json(question_column_name)
    if current_page==1
      result_json[:total] = total_remarks
      result_json[:page_limit] = page_limit
    end
    render :json => result_json
  end

  private

    def set_selected_tab
      @selected_tab = :reports
    end 

    def page_limit
      10
    end
    
    def survey
      @survey ||= current_account.custom_surveys.find(which_survey)
    end

    def survey_question
      @survey_question ||= survey.survey_questions.find(params[:survey_question_id])
    end

    def agents
      current_account.users.technicians.map{ |user| {:id => user.id, :name => user.name} }
    end
    
    def groups
      current_account.groups.map{ |group| {:id => group.id, :name => group.name} }
    end
    
    def surveys_json
      current_account.custom_surveys.with_questions_and_choices.as_reports_json
    end
    
    def which_survey
      params[:survey_id] || current_account.survey.id
    end
    
    def default_params
      {:survey_id => which_survey, :start_date => start_date, :end_date => end_date}
    end

    def total_remarks # avoid this query - used only for pageless plugin
      remarks = survey.survey_results.total_remarks(default_params)
      remarks = filter remarks
      remarks[0].total
    end

    def aggregate_report_data
      survey_questions = survey.survey_questions
      aggregate_report_data = {}
      survey_questions.each do|question|
        condition = default_params
        condition[:column_name] = question.column_name
        results = survey.survey_results.aggregate(condition)
        results = filter results      
        results, unanswered = format_aggregate_report results
        question_wise_result = {
          :unanswered => (question.default? ? unanswered_handles : unanswered),
          :rating => results
        }
        aggregate_report_data["#{question.name}"] = question_wise_result if results.present?
      end
      aggregate_report_data
    end

    def filter scope, column_name=nil
      scope = scope.group_filter(params[:group_id]) if group?
      scope = scope.agent_filter(params[:agent_id]) if agent? 
      scope = scope.rating_filter({
        :column_name => column_name,
        :value => params[:rating]
      }) if params[:rating] && column_name.present? #used only for remarks filtering
      scope
    end

    def format_aggregate_report results
      formatted_result = []
      unanswered = 0
      results.each do |result| 
        if result[:rating].present?
          formatted_result << {
            :survey_id => result[:survey_id], 
            :rating => result[:rating],
            :total => result[:total]
          }
        else
          unanswered = result[:total]
        end
      end
      [formatted_result, unanswered]
    end

    def unanswered_handles
      date_range = {:start_date => start_date , :end_date => end_date}
      handles = survey.survey_handles.unrated(date_range)
      handles = filter handles
      handles.count
    end

    def agent_wise_report_data
      condition = default_params
      condition[:column_name] = survey_question.column_name
      results = survey.survey_results.agent_wise(condition)
      generate_report(results)
    end

    def group_wise_report_data
      condition = default_params
      condition[:column_name] = survey_question.column_name
      results = survey.survey_results.group_wise(condition)
      generate_report(results)
    end    

    def generate_report results
      results = filter results
      format_scoped_report results
    end

    def format_scoped_report results
      formatted_results = {}
      results.each do |result|
        key = result[:id]
        if formatted_results[key].blank?
          formatted_results[key] = {:id => result[:id], :total => 0, :rating => {}}
        end
        formatted_results[key][:rating][result[:rating]] = result[:total].to_i
        formatted_results[key][:total] += result[:total].to_i if result[:rating].present?
      end
      formatted_results
    end

    def agent?
      (params[:agent_id] && params[:agent_id] != AGENT_ALL_URL_REF)
    end

    def group?
      (params[:group_id] && params[:group_id] != GROUP_ALL_URL_REF)
    end
  
    def current_page
      params[:page] = 1 if params[:page].blank?
      params[:page]
    end

end