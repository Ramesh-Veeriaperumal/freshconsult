class AttachmentDecorator < ApiDecorator
  delegate :id, :content_file_name, :content_file_size, :content_content_type,
           :attachment_url_for_api, :inline_url, :attachable_type, to: :record

  def to_hash
    ret_hash = {
      id: id,
      name: content_file_name,
      content_type: content_content_type,
      size: content_file_size,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      attachment_url: attachment_url_for_api #See if this is needed in all cases
    }
    ret_hash[:inline_url] = inline_url if record.inline_image?

    ret_hash[:is_shared] = true if attachable_type == 'Account'
    ret_hash
  end
end
