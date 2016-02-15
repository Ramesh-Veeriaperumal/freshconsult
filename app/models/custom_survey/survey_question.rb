class CustomSurvey::SurveyQuestion < ActiveRecord::Base
  self.table_name = :survey_questions
  self.primary_key = :id
  belongs_to_account
  belongs_to :survey
  
  DEFAULT_FIELD_PROPS = {}
  CUSTOM_FIELDS_SUPPORTED = [:custom_survey_radio]
  DB_COLUMNS = {
    :integer_11   => { :column_name => "cf_int", :column_limits => 21 }
  }

  inherits_custom_field :form_class => 'CustomSurvey::Survey', :form_id => :survey_id,
                    :custom_form_method => :survey_method,
                    :field_data_class => 'CustomSurvey::SurveyResultData',
                    :field_choices_class => 'CustomSurvey::SurveyQuestionChoice'

  validates :name, uniqueness: {scope: [:account_id, :survey_id], message: I18n.t('admin.surveys.thanks_contents.question_error_text')}
  validates_presence_of :name , :label

  acts_as_list scope: [:account_id, :survey_id]

  attr_accessible :survey_id, :name, :column_name, :label, :position, :field_type, :default, :custom_field_choices_attributes  

  scope :default, :conditions => {:default  => true}
  scope :feedback, :conditions => {:default => false}

  xss_sanitize :only => [:name, :label], :plain_sanitizer => [:label, :name]
 
  def survey_method(param_survey_id)
    (Account.current || account).custom_surveys.find_by_id(param_survey_id)
  end
end