class Helpdesk::Attachment < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = ["created_at", "updated_at"]
  acts_as_api

  api_accessible :central_publish do |t|
    t.add :id
    t.add :account_id
    t.add :description
    t.add :content_file_name, as: :file_name
    t.add :content_content_type, as: :content_type
    t.add :content_file_size, as: :file_size
    t.add :attachable_id
    t.add :attachable_type
    t.add :attachment_url 
    DATETIME_FIELDS.each do |key|
      t.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end

  def attachment_url
    inline_image ? "" : attachment_url_for_api(true, :original, 1.day)
  end
end