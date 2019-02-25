class CustomSurvey::SurveyResult < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |sr|
    sr.add :id
    sr.add :account_id
    sr.add :survey_id
    sr.add :surveyable_id
    sr.add :customer_id
    sr.add :agent_id
    sr.add :response_note_id
    sr.add :get_old_rating, as: :rating
    sr.add :group_id
    sr.add proc { |s| s.survey_result_data_payload(true) }, as: :custom_fields
    sr.add proc { |s| s.utc_format(s.created_at) }, as: :created_at
    sr.add proc { |s| s.utc_format(s.updated_at) }, as: :updated_at
  end

  api_accessible :central_publish_associations do |s|
    s.add :survey, template: :central_publish
    s.add :_surveyable, as: :surveyable
  end

  def relationship_with_account
    'custom_survey_results'
  end

  def _surveyable
    {
      id: surveyable_id,
      _model: surveyable_type
    }
  end

  def get_old_rating
    old_rating(rating)
  end
end
