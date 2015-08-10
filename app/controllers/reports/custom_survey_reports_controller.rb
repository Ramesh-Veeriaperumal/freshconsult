class Reports::CustomSurveyReportsController < ApplicationController

  before_filter { |c| c.requires_feature :custom_survey }

  before_filter :set_selected_tab, :only => :index
  before_filter :load_survey

  include Reports::CustomSurveyReport
  include ApplicationHelper

  LIST_LIMIT = 90
  
  AGENT_ALL_URL_REF = 'a'
  GROUP_ALL_URL_REF = 'g'
  RATING_ALL_URL_REF = 'r'

  def index

    reports_list
    @surveys = surveys
    @agents = agents
    @groups = groups
    @unanswered = unanswered
    @question_list = question_list
    @questions_result = @question_list[:questions_result]
    @group_wise_report = @question_list[:group_wise_report]
    @agent_wise_report = @question_list[:agent_wise_report]
    @default_all_values = {:agent => AGENT_ALL_URL_REF,:group => GROUP_ALL_URL_REF,:rating => RATING_ALL_URL_REF}

  end
  
  def reports
    reports_list
    render :json => {:unanswered => unanswered, :questions_result => @question_list[:questions_result].to_json, 
                :group_wise_report => @question_list[:group_wise_report].to_json,
                :agent_wise_report => @question_list[:agent_wise_report].to_json}
  end
  
  def remarks   
    remarks = @survey.survey_results.remarks(default_params)
    default_question_column_name = @survey.default_question.column_name
    remarks = filter remarks, default_question_column_name
    remarks = remarks.paginate(:page => current_page, :per_page => page_limit)
    customer_avatars = avatars(remarks)
    results = remarks.to_json({
                    :only => [:id,:rating,:created_at], :include => { 
                            :survey_remark => {:include => {:feedback => {:only => [:body]}}},
                            :surveyable => { :only => [:display_id, :subject] },
                            :customer => {:only => [:id,:name]},
                            :agent => {:only => [:id,:name]},
                            :group => {:only => [:id,:name]}
                        }
                   })
    results = JSON.parse(results).collect{|obj| obj['survey_result']}
    results.each_with_index do |remark,index|
    if remark["survey_remark"].blank?
      results[index]["survey_remark"] = {"feedback" => {"body" => I18n.t('support.surveys.feedback_not_given')}}
    end
    results[index]["rating"] = remark["rating"]
      results[index]["customer"]["avatar"] = customer_avatars[remark["id"]]
    end
    result_json = {:remarks => results}
    if current_page==1
      result_json[:total] = total_remarks
      result_json[:page_limit] = page_limit
      generate_report_summary(result_json)
    end
    render :json => result_json
    end

private

  def unanswered
    survey_id = which_survey
    date_range = {:start_date => start_date , :end_date => end_date}
    handles = current_account.custom_surveys.find(survey_id).survey_handles.unrated(date_range)
    handles = filter handles
    handles.count
  end
  
  def load_survey
    @survey = current_account.custom_surveys.find(which_survey)
  end

  def reports_list

    @question_list = question_list

  end 

  def generate_report_summary result_json
    reports_list
    result_json[:survey_report_summary] = {}
    result_json[:survey_report_summary][:unanswered] = unanswered
    result_json[:survey_report_summary][:questions_result] = @question_list[:questions_result].to_json
    result_json[:survey_report_summary][:group_wise_report] = @group_wise_report.to_json
    result_json[:survey_report_summary][:agent_wise_report] = @agent_wise_report.to_json

    result_json
  end

  def generate_reports_list survey_reports
    
      reports = {:survey_id => which_survey, :rating => {}, :total => 0, :type => SurveyResult::RATING}
        
      survey_reports.each do |report|
          next if report[:rating].blank?  
          reports[:rating][report[:rating].to_i] = report[:total].to_i
          reports[:total] += report[:total].to_i

      end
  
      reports

      end
  
  def generate_report condition, type
    survey_reports = (type == AGENT_ALL_URL_REF) ? @survey.survey_results.agent_wise(condition)
                             : @survey.survey_results.group_wise(condition)
    survey_reports = filter survey_reports
    format_report survey_reports
  end

  def format_report survey_reports

      reports = Hash.new

      survey_reports.each do |report|
        
        key = report[:id]

        if reports[key].blank?
          reports[key] = {:id=>report[:id], :name => report[:name], :total => 0, :rating => {}}
        end

        reports[key][:rating][report[:rating].to_i] = report[:total].to_i
        reports[key][:total] += report[:total].to_i

      end

      reports

  end 

  def agents
    current_account.agents.includes(:user).collect{|agent| {"id"=>agent.id,"created_at"=>agent.created_at,"user"=>{"name"=>agent.user.name,"id"=>agent.user.id}}}
  end
  
  def groups
    current_account.groups.collect{|group| {"id"=>group.id,"created_at"=>group.created_at,"name"=>group.name,"description"=>group.description}}
  end
  
  def surveys
         JSON.parse(current_account.custom_surveys.to_json({
          :only => [:id,:title_text,:choices,:link_text,:active,:created_at,:can_comment], 
          :methods => :choices,
          :include => { 
                  :survey_questions => {
                            :only =>[:id,:name,:label],
                            :methods => :choices
                           }
                }
    })).collect{|obj| obj["survey"]}
     end
  
  def which_survey
    (params[:survey_id] || (
        !(current_account.custom_surveys.blank?) ? 
          (!(current_account.custom_surveys.active.blank?) ? 
            current_account.custom_surveys.active.first.id : current_account.custom_surveys.first.id) : null))
  end
  
  def default_params
    {:survey_id => which_survey, :start_date => start_date, :end_date => end_date}
  end
  
  def avatars remarks #needs to be optimized
    customer_avatars = Hash.new
    remarks.each_with_index do |remark,index|
      customer_avatars[remark.id] = user_avatar_url(remark.customer)
    end 
    customer_avatars
  end

    def total_remarks
    remarks = @survey.survey_results.total_remarks(default_params)
    remarks = filter remarks
    remarks[0].total
    end
  
    def set_selected_tab
      @selected_tab = :reports
    end 

    def page_limit
      return 10
    end
    
    def format_result results
      results_json = []
      results.each do |result|
        next if result[:rating].blank?
        results_json << {
                                  "id" => result[:id],
                                  "survey_id" => result[:survey_id], 
                                  "rating" => result[:rating],
                                  "total" => result[:total]
                              }
      end
      results_json
    end

    def question_list
    survey = current_account.custom_surveys.find(which_survey)
    survey_questions = survey.survey_questions
    questions_result = {}
    group_wise_report = {}
    agent_wise_report = {}
    survey_questions.each do|question|
      condition = default_params
      condition[:column_name] = question.column_name
      results = survey.survey_results.report(condition)
      results = filter results      
      results = format_result results
      question_result = {
          :rating => results,
          :default => question.default
      }
      unless question_result[:rating].blank?
        questions_result["#{question.name}"]  =  question_result
        group_wise_report["#{question.name}"] =  JSON.parse(generate_report(condition,GROUP_ALL_URL_REF).to_json) unless group?
        agent_wise_report["#{question.name}"] =  JSON.parse(generate_report(condition,AGENT_ALL_URL_REF).to_json) unless agent?
      end
    end
    list = { :questions_result => questions_result }
    list[:group_wise_report] = group_wise_report unless group?
    list[:agent_wise_report] = agent_wise_report unless agent?
    list
    end
    
    def filter scope, column_name=nil
    scope = scope.group_filter(params[:group_id]) if group?
    scope = scope.agent_filter(params[:agent_id]) if agent? 
    scope = scope.rating_filter({
          :column_name => column_name,
          :value => params[:rating]
        }) if rating? && !column_name.blank?
    scope
    end

    def question?
      (params[:category].blank? || params[:category] == CustomSurvey::Survey::Question)
    end
  
    def agent?
      (params[:agent_id] && params[:agent_id] != AGENT_ALL_URL_REF)
    end

    def group?
      (params[:group_id] && params[:group_id] != GROUP_ALL_URL_REF)
    end
    
    def rating?
   (params[:rating] && params[:rating] != RATING_ALL_URL_REF)
    end
  
    def current_page
      params[:page] = 1 if params[:page].blank?

      params[:page]
    end

end