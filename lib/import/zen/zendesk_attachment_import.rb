class Import::Zen::ZendeskAttachmentImport 	
  extend Resque::AroundPerform
  @queue = 'ImportAttachmentWorker'

  def self.perform(args)
    Import::Attachment.new(args).perform
  end
end