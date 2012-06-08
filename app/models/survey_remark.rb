class SurveyRemark < ActiveRecord::Base
	
	belongs_to_account
	belongs_to :survey_result,:class_name => 'SurveyResult', :foreign_key => :survey_result_id
	belongs_to :feedback,:class_name => 'Helpdesk::Note', :foreign_key => :note_id

end