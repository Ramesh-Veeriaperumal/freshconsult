module CustomSurveyResultKey
  CONFIG = YAML.load_file(Rails.root.join('config', 'custom_survey_result_key.yml'))[Rails.env]['key']
end
