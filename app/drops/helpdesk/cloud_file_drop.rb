class Helpdesk::CloudFileDrop < BaseDrop
  
  include ActionView::Helpers::NumberHelper
  include ActionController::UrlWriter
    
  def initialize(source)
    super source
  end
  
  def url
    source.url
  end

  def thumbnail    
    extname = (["pdf", "doc", "mov", "xls", "zip", "txt", "ppt"].include?(extension)) ? extension : "def"
    "/images/portal/file-type/#{extname}.png"
  end

  def extension
    @extension ||= filename.split('.')[-1]
  end

  def filename
    @filename ||= (source.filename || source.url.split('/')[-1] )
  end

  def delete_url
    helpdesk_cloud_file_path(source)
  end

  def provider
    source.provider
  end

end