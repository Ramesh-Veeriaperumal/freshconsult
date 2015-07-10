class CustomSurvey::SurveyRemark < ActiveRecord::Base
	self.primary_key = :id
  	self.table_name = :survey_remarks
	belongs_to_account
	belongs_to :survey_result,:class_name => 'CustomSurvey::SurveyResult', :foreign_key => :survey_result_id
	belongs_to :feedback,:class_name => 'Helpdesk::Note', :foreign_key => :note_id
end