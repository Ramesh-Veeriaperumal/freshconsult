module Ember
  class SurveysController < ::SurveysController
    # Whenever we change the Structure (add/modify/remove keys), we will have to modify the below constant
    CURRENT_VERSION = 'private-v1'.freeze
    send_etags_along(CustomSurvey::Survey::VERSION_MEMBER_KEY)

    def scoper
      custom_survey? ? current_account.custom_surveys.undeleted.preload(survey_questions: [:survey, :custom_field_choices_desc]) : default_survey
    end

    def load_object
      @item = current_account.custom_surveys.with_questions_and_choices.find_by_id(params[:id])
      log_and_render_404 unless @item
    end

    def decorator_options
      super(version: 'private')
    end
  end
end
