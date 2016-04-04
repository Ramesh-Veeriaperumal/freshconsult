class CustomSurvey::Survey < ActiveRecord::Base
  belongs_to_account
  has_many :survey_handles, :class_name => 'CustomSurvey::SurveyHandle', :foreign_key => :survey_id, :dependent => :destroy
  #custom_survey_handles is a temporary fix to access survey_handles through current_account in support
  has_many :custom_survey_handles, :class_name => 'CustomSurvey::SurveyHandle', :foreign_key => :survey_id, :dependent => :destroy
  has_many :survey_results, :class_name => 'CustomSurvey::SurveyResult', :foreign_key => :survey_id, :dependent => :destroy
  has_many :custom_survey_results, :class_name => 'CustomSurvey::SurveyResult', :foreign_key => :survey_id, :dependent => :destroy
  has_many :survey_questions, :class_name => 'CustomSurvey::SurveyQuestion', :foreign_key => :survey_id,
            :conditions => {:deleted => false}, :include => [:custom_field_choices], :order => "position"

  acts_as_custom_form :custom_field_class => 'CustomSurvey::SurveyQuestion', :custom_fields_cache_method => :survey_questions

  accepts_nested_attributes_for :survey_questions

  scope :with_questions_and_choices, :include => :survey_questions
  scope :active, :conditions => { :active => true }
  scope :default, :conditions => { :default => true }
  scope :custom,  :conditions => { :default => false }
  scope :deleted, :conditions => { :deleted => true }
  scope :undeleted, :conditions => { :deleted => false }
  
  validates :title_text, uniqueness: {scope: [:account_id, :deleted], message: I18n.t('admin.surveys.new_layout.title_error_text')}

  validates_length_of :title_text , :maximum => TITLE_TEXT_LIMIT

  validates_length_of :link_text, :thanks_text , :maximum => LINK_TEXT_LIMIT
end