module Admin::CustomSurveysHelper
  def custom_survey_url(survey_handle, rating, language = nil)
    host = survey_handle.try(:surveyable).try(:portal_host) || Account.current.host
    host += "/#{language.code}" if language.present?
    support_customer_custom_survey_url(survey_handle.id_token, CustomSurvey::Survey::CUSTOMER_RATINGS[rating],
                                       protocol: Account.current.url_protocol, host: host)
  end
end
