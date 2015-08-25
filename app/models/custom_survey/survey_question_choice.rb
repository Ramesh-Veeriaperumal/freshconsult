class CustomSurvey::SurveyQuestionChoice < ActiveRecord::Base

 self.table_name = :survey_question_choices
 self.primary_key = :id	

 belongs_to_account

 stores_custom_field_choice  :custom_field_class => 'CustomSurvey::SurveyQuestion', 
                      :custom_field_id => :survey_question_id

 attr_accessible :value, :position, :face_value, :id

 validates_inclusion_of :face_value, :in => [
                                                                  	CustomSurvey::Survey::EXTREMELY_HAPPY,
                                                                  	CustomSurvey::Survey::VERY_HAPPY,
                                                                     	CustomSurvey::Survey::HAPPY,
                                                                  	CustomSurvey::Survey::NEUTRAL,
                                                                  	CustomSurvey::Survey::UNHAPPY,
                                                                  	CustomSurvey::Survey::VERY_UNHAPPY,
                                                                  	CustomSurvey::Survey::EXTREMELY_UNHAPPY
                                                                  ]

xss_sanitize :only => [:value], :plain_sanitizer => [:value]

end