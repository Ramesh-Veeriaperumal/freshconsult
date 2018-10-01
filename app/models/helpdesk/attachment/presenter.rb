class Helpdesk::Attachment < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = ["created_at", "updated_at"]
  acts_as_api

  api_accessible :central_publish do |t|
    t.add :id
    t.add :name
    t.add :content_type
    t.add :size
    t.add :attachment_url
    DATETIME_FIELDS.each do |key|
      t.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end

  end
end