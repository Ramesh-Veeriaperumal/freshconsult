module Ember
  class SurveysController < ::SurveysController
    # Whenever we change the Structure (add/modify/remove keys), we will have to modify the below constant
    CURRENT_VERSION = 'private-v1'.freeze
    send_etags_along('SURVEY_LIST')

    def scoper
      custom_survey? ? current_account.custom_surveys.undeleted.preload(survey_questions: [:survey, :custom_field_choices_desc]) : default_survey
    end

    def decorator_options
      super(version: 'private')
    end
  end
end
