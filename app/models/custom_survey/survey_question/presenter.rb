class CustomSurvey::SurveyQuestion < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api

  api_accessible :central_publish do |sq|
    sq.add :id
    sq.add :account_id
    sq.add :survey_id
    sq.add :name
    sq.add :field_type
    sq.add :position
    sq.add :deleted
    sq.add :label
    sq.add :column_name
    sq.add :default
    sq.add proc { |t| t.utc_format(t.created_at) }, as: :created_at
    sq.add proc { |t| t.utc_format(t.updated_at) }, as: :updated_at
  end

  api_accessible :central_publish_destroy do |sq|
    sq.add :id
    sq.add :account_id
    sq.add :survey_id
  end

  api_accessible :central_publish_associations do |s|
    s.add :survey, template: :central_publish
  end

  def relationship_with_account
    'custom_survey_questions'
  end
end
