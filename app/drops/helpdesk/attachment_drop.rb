class Helpdesk::AttachmentDrop < BaseDrop
  
  include ActionView::Helpers::NumberHelper
  include ActionController::UrlWriter
    
  def initialize(source)
    super source
  end
  
  def url
    helpdesk_attachment_path(source)
  end

  def thumbnail
    if source.image?
      "/images/helpdesk/attachments/#{source.id}/thumb"
    else
      extname = source.content_file_name.split('.')[-1] 
      extname = (["pdf", "doc", "mov", "xls", "zip", "txt", "ppt"].include?(extname)) ? extname : "def"
      "/images/portal/file-type/#{extname}.png"
    end
  end

  def extension
    source.content_file_name.split('.')[-1]
  end

  def filename
    source.content_file_name
  end

  def size
    number_to_human_size source.content_file_size
  end

  def is_image?
    source.image?
  end

  def delete_url
    helpdesk_attachment_path(source)
  end

end