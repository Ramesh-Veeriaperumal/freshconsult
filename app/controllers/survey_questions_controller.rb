class SurveyQuestionsController < ApplicationController
  
  private

    def scoper_class
      SurveyQuestion
    end

    def index_scoper
      # @index_scoper ||= current_portal.contact_fields # saves MemCache calls # TODO
      current_portal.survey_questions
    end

    def scoper(account = current_account)
      account.survey_questions
    end
end
