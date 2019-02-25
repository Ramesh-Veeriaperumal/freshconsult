class SurveyHandle < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api

  api_accessible :central_publish do |sh|
    sh.add :id
    sh.add :account_id
    sh.add :surveyable_id
    sh.add :id_token
    sh.add :send_while_hash, as: :sent_while
    sh.add :response_note_id
    sh.add proc { |t| t.utc_format(t.created_at) }, as: :created_at
    sh.add proc { |t| t.utc_format(t.updated_at) }, as: :updated_at
    sh.add :survey_id
    sh.add :survey_result_id
    sh.add :rated
    sh.add :preview
    sh.add :agent_id
    sh.add :group_id
  end

  api_accessible :central_publish_destroy do |sh|
    sh.add :id
    sh.add :account_id
    sh.add :survey_id
    sh.add :surveyable_id
    sh.add :send_while_hash, as: :sent_while
    sh.add proc { |t| t.utc_format(t.created_at) }, as: :created_at
    sh.add proc { |t| t.utc_format(t.updated_at) }, as: :updated_at
  end

  api_accessible :central_publish_associations do |s|
    s.add :survey, template: :central_publish
    s.add :survey_questions, template: :central_publish
    s.add :_surveyable, as: :surveyable
  end

  def _surveyable
    {
      id: surveyable_id,
      _model: surveyable_type
    }
  end
end
