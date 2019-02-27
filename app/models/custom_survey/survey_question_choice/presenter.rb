class CustomSurvey::SurveyQuestionChoice < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api

  api_accessible :central_publish do |sq_choice|
    sq_choice.add :id
    sq_choice.add :account_id
    sq_choice.add :survey_question_id
    sq_choice.add :value
    sq_choice.add :face_value
    sq_choice.add :position
    sq_choice.add proc { |t| t.utc_format(t.created_at) }, as: :created_at
    sq_choice.add proc { |t| t.utc_format(t.updated_at) }, as: :updated_at
  end

  api_accessible :central_publish_destroy do |sq_choice|
    sq_choice.add :id
    sq_choice.add :account_id
  end

  api_accessible :central_publish_associations do |s|
    s.add :survey_question, template: :central_publish
  end
end
