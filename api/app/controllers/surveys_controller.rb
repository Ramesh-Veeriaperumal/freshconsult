class SurveysController < ApiApplicationController
  decorate_views

  def scoper
    custom_survey? ? current_account.custom_surveys.undeleted : default_survey
  end

  def feature_name
    FeatureConstants::SURVEYS
  end

  def validate_filter_params
    params.permit(:state, *ApiConstants::DEFAULT_INDEX_FIELDS)
    survey_filter = SurveyFilterValidation.new(params, nil, true)
    render_errors(survey_filter.errors, survey_filter.error_options) unless survey_filter.valid?
  end

  def load_objects(_items = scoper)
    super survey_filter
  end

  def survey_filter
    params[:state] == 'active' ? fetch_active_survey : scoper
  end

  def fetch_active_survey
    custom_survey? ? Array.wrap(current_account.active_custom_survey_from_cache) : fetch_active_default_survey
  end

  def fetch_active_default_survey
    Account.current.features?(:survey_links) ? default_survey : []
  end

  def default_survey
    Array.wrap(current_account.survey)
  end

  def custom_survey?
    @custom_survey ||= current_account.new_survey_enabled?
  end

  def decorator_options(options = {})
    super({ custom_survey: @custom_survey }.merge(options))
  end
end
