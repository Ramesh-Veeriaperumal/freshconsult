class CustomSurvey::SurveyResultData < ActiveRecord::Base
  self.table_name =  :survey_result_data
  self.primary_key = :id
    
  belongs_to_account
  stores_custom_field_data  :parent_id => :survey_result_id, :parent_class => 'CustomSurvey::SurveyResult', 
                            :form_id => :survey_id, :form_class => 'CustomSurvey::Survey', 
                            :custom_form_cache_method => :custom_form
end