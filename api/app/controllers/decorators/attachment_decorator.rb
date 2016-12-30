class AttachmentDecorator < ApiDecorator

  def to_hash
    ret_hash = {
      id: record.id,
      name: record.content_file_name,
      content_type: record.content_content_type,
      size: record.content_file_size,
      created_at: record.created_at.try(:utc),
      updated_at: record.updated_at.try(:utc),
      attachment_url: record.attachment_url_for_api #See if this is needed in all cases
    }
    ret_hash.merge!(inline_url: record.inline_url) if record.inline_image?
    ret_hash
  end

end
