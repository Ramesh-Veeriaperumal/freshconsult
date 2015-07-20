account = Account.current

survey = CustomSurvey::Survey.seed(:account_id) do |s|
  s.account_id = account.id
  s.title_text = "Default Survey"
  s.link_text = 'Please tell us what you think of your support experience.'
  s.thanks_text = "Thank you very much for your feedback."
  s.happy_text = "Awesome"
  s.neutral_text = "Just Okay"
  s.unhappy_text = "Not Good"
  s.can_comment = true
  s.feedback_response_text = "Thank you. Your feedback has been sent."
  s.active = true
  s.send_while = Survey::RESOLVED_NOTIFICATION
  s.comments_text = "Add more details about customer experience."
  s.default = true
end

# CustomSurvey::SurveyQuestion.seed(:account_id) do |q|
#   q.survey_id = survey.id
#   q.name = 'default_survey_question'
#   q.label = 'How would you rate your overall satisfaction for the resolution provided by the agent?'
#   q.column_name = "cf_int01"
#   q.position = 1
#   q.field_type = :custom_survey_radio
#   q.default = true
#   q.custom_field_choices_attributes =[
#             { :position => 1, :_destroy => 0, :value => "Disagree", :face_value => CustomSurvey::Survey::EXTREMELY_UNHAPPY },
#             { :position => 2, :_destroy => 0, :value => "Neutral", :face_value => CustomSurvey::Survey::NEUTRAL },
#             { :position => 3, :_destroy => 0, :value => "Agree", :face_value => CustomSurvey::Survey::EXTREMELY_HAPPY }
#   ]
# end