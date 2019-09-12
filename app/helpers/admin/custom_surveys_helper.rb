module Admin::CustomSurveysHelper
  def custom_survey_url(survey_handle, rating, language = nil)
    host = survey_handle.try(:surveyable).try(:portal_host) || Account.current.host
    host += "/#{language.code}" if language.present?
    support_customer_custom_survey_url(survey_handle.id_token, CustomSurvey::Survey::CUSTOMER_RATINGS[rating],
                                       protocol: Account.current.url_protocol, host: host)
  end

  def preview_custom_survey_url(survey)
    host = Account.current.host
    support_custom_survey_preview_questions_url(survey.id, protocol: Account.current.url_protocol, host: host)
  end

  def languages_status(languages)
    language_items = []
    languages.each do |language|
      status_key = @survey && @survey_statuses[language.id] ? @survey_statuses[language.id] : CustomTranslation::SURVEY_STATUS[:untranslated]
      language_items.push(language.as_json.merge!('status' => status_key))
    end
    language_items
  end

  def portal_languages_status
    languages = Account.current.portal_languages_objects
    languages_status languages
  end

  def hidden_languages_status
    languages = Account.current.supported_languages_objects - Account.current.portal_languages_objects
    languages_status languages
  end

  def fetch_current_time
    Time.zone.now.strftime('%I:%M %p, %a %d %b %Y')
  end

  def survey_language_preview(language_code)
    "#{Account.current.url_protocol}://#{Account.current.full_domain}/#{language_code}/support/custom_surveys/#{@survey.id}/preview"
  end
end
