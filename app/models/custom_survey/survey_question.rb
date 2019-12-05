class CustomSurvey::SurveyQuestion < ActiveRecord::Base
  self.table_name = :survey_questions
  self.primary_key = :id
  belongs_to_account
  belongs_to :survey

  include Surveys::PresenterHelper
  include MemcacheKeys
  
  DEFAULT_FIELD_PROPS = {}
  CUSTOM_FIELDS_SUPPORTED = [:custom_survey_radio]
  DB_COLUMNS = {
    :integer_11   => { :column_name => "cf_int", :column_limits => 21 }
  }

  inherits_custom_field :form_class => 'CustomSurvey::Survey', :form_id => :survey_id,
                    :custom_form_method => :survey_method,
                    :field_data_class => 'CustomSurvey::SurveyResultData',
                    :field_choices_class => 'CustomSurvey::SurveyQuestionChoice'

  has_many  :custom_field_choices_asc, :class_name => '::CustomSurvey::SurveyQuestionChoice',
                  :order => 'face_value', :dependent => :destroy

  has_many  :custom_field_choices_desc, :class_name => '::CustomSurvey::SurveyQuestionChoice',
                  :order => 'face_value DESC', :dependent => :destroy

  def custom_field_choices
    @custom_field_choices ||= (survey.good_to_bad? ? custom_field_choices_desc : custom_field_choices_asc)
  end

  validates :name, uniqueness: {scope: [:account_id, :survey_id, :deleted], message: I18n.t('admin.surveys.thanks_contents.question_error_text')}
  validates_presence_of :name , :label

  acts_as_list scope: [:account_id, :survey_id]

  attr_accessible :survey_id, :name, :label, :position, :field_type, :default, :custom_field_choices_attributes  

  scope :default, :conditions => {:default  => true}
  scope :feedback, :conditions => {:default => false}

  xss_sanitize :only => [:name, :label], :plain_sanitizer => [:label, :name]

  before_destroy :deleted_survey_model_info
  publishable
  concerned_with :presenter

  after_commit :clear_survey_map_cache

  def survey_method(param_survey_id)
    (Account.current || account).custom_surveys.find_by_id(param_survey_id)
  end

  def face_values
    choices.map { |c| c[:face_value] }
  end

  def clear_survey_map_cache
    key = format(SURVEY_QUESTIONS_MAP_KEY, account_id: account_id, survey_id: survey_id)
    delete_value_from_cache(key)
  end
end
