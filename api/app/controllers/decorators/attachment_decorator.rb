class AttachmentDecorator < ApiDecorator
  delegate :id, :name, :content_type, :created_at, :updated_at, :attachment_url_for_api, to: :record

  def to_hash
    {
      id: record.id,
      name: record.content_file_name,
      content_type: record.content_content_type,
      size: record.content_file_size,
      created_at: record.created_at.try(:utc),
      updated_at: record.updated_at.try(:utc),
      attachment_url: record.attachment_url_for_api #See if this is needed in all cases
    }
  end

end
