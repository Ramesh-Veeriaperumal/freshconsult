class CustomSurvey::SurveyResult < ActiveRecord::Base
  attr_accessible :survey_id, :surveyable_id, :surveyable_type, :customer_id, :agent_id, :group_id, :response_note_id, :rating

  belongs_to_account  
  has_one :survey_remark, :class_name => 'CustomSurvey::SurveyRemark', :foreign_key => :survey_result_id, :dependent => :destroy
  has_one :survey_result_data, :dependent => :destroy
  belongs_to :surveyable, :polymorphic => true
  belongs_to :survey, :class_name => 'CustomSurvey::Survey', :foreign_key => :survey_id
  belongs_to :agent, :class_name => 'User', :foreign_key => :agent_id, :conditions => {:deleted => false}
  belongs_to :customer, :class_name => 'User', :foreign_key => :customer_id
  belongs_to :group, :class_name => 'Group', :foreign_key => :group_id
  belongs_to :response_note, :class_name => 'Helpdesk::Note'

  has_custom_fields :class_name => 'CustomSurvey::SurveyResultData', :discard_blank => true

  scope :remarks , lambda { |condition|
    preload([{:survey_remark => { :feedback => [:note_old_body]} }, :surveyable, :survey_result_data,
      {:customer => :avatar}, :agent, :group]).
          where("survey_results.survey_id= ? 
            and survey_results.created_at between ? and ?", 
            condition[:survey_id], condition[:start_date], condition[:end_date]).order("survey_results.created_at DESC")
  }

  scope :total_remarks , lambda { |condition| {
    :select => "count(*) as total",
    :conditions => ["survey_results.survey_id= ?  
                      and survey_results.created_at between ? and ?", 
                      condition[:survey_id], condition[:start_date], condition[:end_date]]
  }}

  scope :rating_filter, lambda { |condition| 
    query_condition = (condition[:value] == RATING_ALL_URL_REF) ? 
                        ["survey_result_data.#{condition[:column_name]} is NOT NULL"] :
                          ["survey_result_data.#{condition[:column_name]}=#{condition[:value]}"]
    { :joins => "INNER JOIN `survey_result_data` ON 
                  `survey_result_data`.`survey_result_id` = `survey_results`.`id` AND 
                    `survey_result_data`.`account_id` = `survey_results`.`account_id`",
      :conditions => query_condition }
  }

  scope :agent_filter, lambda { |agent_id| { 
      :conditions =>  {:agent_id => agent_id} } unless agent_id.blank?
  }

  scope :group_filter, lambda { |group_id| { 
      :conditions =>  {:group_id => group_id} } unless group_id.blank?
  }

  scope :aggregate, lambda { |condition| {
      :select => "`survey_results`.id, `survey_results`.survey_id, 
                    survey_result_data.#{condition[:column_name]} as rating, count(*) as total",
      :joins => "INNER JOIN `survey_result_data` ON
                  `survey_result_data`.`survey_result_id` = `survey_results`.`id` AND
                    `survey_result_data`.`account_id` = `survey_results`.`account_id`",
      :group => "survey_result_data.#{condition[:column_name]}",
      :order => "survey_result_data.#{condition[:column_name]}",
      :conditions => ["survey_results.survey_id = ? 
                        and survey_results.created_at between ? and ?", 
                        condition[:survey_id], condition[:start_date], condition[:end_date]]
  }}

  scope :group_wise, lambda { |condition| { 
      :select => "group_id as id, survey_result_data.#{condition[:column_name]} as rating,
                    count(*) as total",
      :joins => "INNER JOIN `survey_result_data` ON
                  `survey_result_data`.`survey_result_id` = `survey_results`.`id` AND
                    `survey_result_data`.`account_id` = `survey_results`.`account_id`",
      :group => "survey_results.group_id, survey_result_data.#{condition[:column_name]}",
      :order => "survey_result_data.#{condition[:column_name]}",
      :conditions => ["survey_results.survey_id = ? 
                          and survey_results.created_at between ? and ?", 
                          condition[:survey_id], condition[:start_date], condition[:end_date]]
  }}

  scope :agent_wise, lambda {|condition| { 
      :select => "agent_id as id, survey_result_data.#{condition[:column_name]} as rating, 
                    count(*) as total",
      :joins => "INNER JOIN `survey_result_data` ON
                  `survey_result_data`.`survey_result_id` = `survey_results`.`id` AND
                    `survey_result_data`.`account_id` = `survey_results`.`account_id`",
      :group => "survey_results.agent_id, survey_result_data.#{condition[:column_name]}",
      :order => "survey_result_data.#{condition[:column_name]}",
      :conditions => ["survey_results.survey_id = ? 
                        and survey_results.created_at between ? and ?", 
                        condition[:survey_id], condition[:start_date], condition[:end_date]]

  }}

  scope :permissible_survey, lambda { |user| {
    conditions: permissible_condition(user)
  }
  }

  scope :export_data, lambda {|condition| {
    :conditions => ["`survey_results`.`survey_id` = ? and 
                     `survey_results`.`created_at` between ? and ?",
                     condition[:survey_id], condition[:start_date], condition[:end_date]]  
  }}

  class << self
    def permissible_condition user
      if user.assigned_tickets_permission?
        ['agent_id = ?', user.id]
      elsif user.group_tickets_permission?
        ['(group_id IN (?) OR agent_id = ?)', user.associated_group_ids, user.id]
      end
    end
  end
end