class AttachmentDecorator < ApiDecorator
  delegate :id, :content_file_name, :content_file_size, :content_content_type,
           :attachment_url_for_api, :attachment_cdn_url_for_api, :inline_url, :attachable_type, :inline_image?, to: :record

  def initialize(record, expiry = 1.day, thumb = true)
    @record  = record
    @expiry  = expiry
    @thumb   = thumb
  end

  def to_hash(cdn_url = false)
    ret_hash = {
      id: id,
      name: content_file_name,
      content_type: content_content_type,
      size: content_file_size,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      attachment_url: fetch_attachment_url(cdn_url) # See if this is needed in all cases
    }
    ret_hash[:inline_url] = inline_url if inline_image?
    ret_hash[:thumb_url] = attachment_url_for_api(true, :thumb) if record.image? && !inline_image? && @thumb
    ret_hash[:is_shared] = true if attachable_type == 'Account'
    ret_hash
  end

  # Generate attachment URL for CloudFront or S3 based on the account
  # This is done to accelerate attachment load times when in times of network congestions
  def fetch_attachment_url(cdn_url)
    if inline_image?
      inline_url
    elsif cdn_url
      attachment_cdn_url_for_api(true, :original, @expiry)
    else
      attachment_url_for_api(true, :original, @expiry)
    end
  end
end
