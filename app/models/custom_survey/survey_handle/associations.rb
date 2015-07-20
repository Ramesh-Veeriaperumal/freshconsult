class CustomSurvey::SurveyHandle < ActiveRecord::Base

  belongs_to_account	
  belongs_to :survey, :class_name => 'CustomSurvey::Survey'
  belongs_to :surveyable, :polymorphic => true
  belongs_to :response_note, :class_name => 'Helpdesk::Note'
  belongs_to :survey_result, :class_name => 'CustomSurvey::SurveyResult'
  belongs_to :group
  belongs_to :agent

  delegate :portal, :to => :surveyable

  scope :unrated, lambda { |condition| { :conditions => ["rated=false and  
                                          preview=false and 
                                          created_at between '#{condition[:start_date]}' and
                                          '#{condition[:end_date]}'"] } }

  
  scope :agent_filter, lambda { |value| { :conditions => { :agent_id => value } } }
  
  scope :group_filter, lambda { |value| { :conditions => { :group_id => value } } }

end