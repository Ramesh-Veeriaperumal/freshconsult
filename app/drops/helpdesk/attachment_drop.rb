class Helpdesk::AttachmentDrop < BaseDrop
  
  include ActionView::Helpers::NumberHelper
  include Rails.application.routes.url_helpers
    
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
      "/images/portal/file-type/def.png"
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