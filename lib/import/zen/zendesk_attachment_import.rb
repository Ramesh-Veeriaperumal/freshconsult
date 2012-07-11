require 'resque-retry'

class Import::Zen::ZendeskAttachmentImport 
	extend Resque::Plugins::Retry
	
  @queue = 'ImportAttachmentWorker'

  @retry_limit = 3

  def self.perform(note_id,url,model)
  	model = model.to_sym
    Import::Attachment.new(note_id ,url, model).perform
  end
end