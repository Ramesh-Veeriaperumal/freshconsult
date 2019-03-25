class CustomSurvey::Survey < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api

  api_accessible :central_publish do |s|
    s.add :id
    s.add :account_id
    s.add :send_while_hash, as: :send_while
    s.add proc { |t| t.utc_format(t.created_at) }, as: :created_at
    s.add proc { |t| t.utc_format(t.updated_at) }, as: :updated_at
    s.add :title_text
    s.add :active
    s.add :thanks_text
    s.add :feedback_response_text
    s.add :can_comment
    s.add :comments_text
    s.add :default
    s.add :link_text
    s.add :happy_text
    s.add :neutral_text
    s.add :unhappy_text
    s.add :deleted
    s.add :good_to_bad
  end
end
