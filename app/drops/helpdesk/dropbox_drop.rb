class Helpdesk::DropboxDrop < BaseDrop
  
  include ActionView::Helpers::NumberHelper
  include ActionController::UrlWriter
    
  def initialize(source)
    super source
  end
  
  def url
    source.url
  end

  def thumbnail    
    extname = source.url.split('.')[-1] 
    extname = (["pdf", "doc", "mov", "xls", "zip", "txt", "ppt"].include?(extname)) ? extname : "def"
    "/images/portal/file-type/#{extname}.png"
  end

  def extension
    @extension ||= source.url.split('.')[-1]
  end

  def filename
    @filename ||= source.url.split('/')[-1] 
  end

  def delete_url
    helpdesk_dropbox_path(source)
  end

end