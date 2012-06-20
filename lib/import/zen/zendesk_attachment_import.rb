class Import::Zen::ZendeskAttachmentImport 
  @queue = 'ImportAttachmentWorker'

  def self.perform(note_id,url,model)
  	model = model.to_sym
    Import::Attachment.new(note_id ,url, model).perform
  end
end