class CustomSurvey::SurveyHandle < ActiveRecord::Base
  belongs_to_account	
  belongs_to :survey, :class_name => 'CustomSurvey::Survey'
  belongs_to :surveyable, :polymorphic => true
  belongs_to :response_note, :class_name => 'Helpdesk::Note'
  belongs_to :survey_result, :class_name => 'CustomSurvey::SurveyResult'
  belongs_to :group
  belongs_to :agent, :class_name => 'User', :foreign_key => :agent_id, :conditions => {:deleted => false}
  belongs_to :customer, :class_name => 'User', :foreign_key => :customer_id
  has_many :survey_questions, :class_name => 'CustomSurvey::SurveyQuestion', :through => :survey

  scope :unrated, lambda { |condition| { :conditions => ["rated=false and  
                                          preview=false and created_at between ? and ?", 
                                          condition[:start_date], condition[:end_date] ]}}
  scope :agent_filter, lambda { |value| { :conditions => { :agent_id => value } } }
  scope :group_filter, lambda { |value| { :conditions => { :group_id => value } } }
  
  attr_protected :account_id, :survey_result_id, :surveyable_id, :surveyable_type, :rated

  def portal
    surveyable.present? ? surveyable.portal : Account.current.main_portal
  end
end