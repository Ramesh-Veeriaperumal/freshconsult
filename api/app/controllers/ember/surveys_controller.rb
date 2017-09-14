module Ember
  class SurveysController < ::SurveysController
    include DataVersioning::Controller

    def scoper
      custom_survey? ? current_account.custom_surveys.undeleted.preload(survey_questions: [:survey, :custom_field_choices_desc]) : default_survey
    end

    def decorator_options
      super(version: 'private')
    end
  end
end
