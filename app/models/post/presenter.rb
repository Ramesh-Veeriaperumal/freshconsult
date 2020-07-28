class Post < ActiveRecord::Base
  include RepresentationHelper
  DATETIME_FIELDS = [:created_at, :updated_at]

  acts_as_api

  # Skipping body and body_html attributes for now
  api_accessible :central_publish do |pt|
    pt.add :id
    pt.add :user_id
    pt.add :topic_id
    pt.add :forum_id
    pt.add :account_id
    pt.add :answer
    pt.add :import_id
    pt.add :published
    pt.add :spam
    pt.add :trash
    pt.add :user_votes
    pt.add proc { |x| !x.original_post? }, as: :comment
    DATETIME_FIELDS.each do |key|
      pt.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end

  api_accessible :central_publish_associations do |t|
    t.add :user, template: :central_publish
  end
end
