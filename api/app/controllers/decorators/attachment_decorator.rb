class AttachmentDecorator < ApiDecorator
  delegate :id, :content_file_name, :content_file_size, :content_content_type,
           :attachment_url_for_api, :inline_url, :attachable_type, :shared_attachments, to: :record

  def initialize(record, options = {})
    super(record)
    @shared_attachable_id = options[:shared_attachable_id]
  end

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
    ret_hash.merge!(inline_url: inline_url) if record.inline_image?

    if @shared_attachable_id && attachable_type == 'Account'
      ret_hash.merge!(shared_attachment_id: shared_attachment_id)
    end
    ret_hash
  end

  def shared_attachment_id
    shared_attachments.where(shared_attachable_id: @shared_attachable_id).first.id
  end

end
