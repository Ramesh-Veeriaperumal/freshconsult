class Import::Zen::ZendeskAttachmentImport 	
  extend Resque::AroundPerform
  @queue = 'ImportAttachmentWorker'

  def self.perform(args)
  	model = args[:model].to_sym
    Import::Attachment.new(args[:item_id] ,args[:attachment_url], model).perform
  end
end