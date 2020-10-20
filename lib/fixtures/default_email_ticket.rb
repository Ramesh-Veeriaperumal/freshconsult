class Fixtures::DefaultEmailTicket < Fixtures::DefaultTicket

  private
    def description_html
      @description_html ||= I18n.t("default.ticket.#{source_name}.body")
    end

    def source
      Helpdesk::Source::EMAIL
    end

    def type
      #REVISIT . Need to change this after ticket constants I18n dependencies are moved to class methods
      I18n.t('question')
    end

    def created_at
      account.created_at - 1.hour - 3.minute
    end

    def after_create
      #current_user is reset so that survey goes from customer.
      current_user = User.current
      User.reset_current_user

      survey = account.custom_surveys.default.first

      survey_handle = ticket.custom_survey_handles.build(
        :survey => survey,
        :sent_while => CustomSurvey::Survey::CLOSED_NOTIFICATION
      )

      survey_handle.record_survey_result  CustomSurvey::Survey::CUSTOMER_RATINGS_BY_TOKEN["extremely_happy"]

      current_user.make_current
    end
end