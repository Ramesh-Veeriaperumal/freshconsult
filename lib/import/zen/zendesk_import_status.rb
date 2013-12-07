class Import::Zen::ZendeskImportStatus
  extend Resque::AroundPerform
  @queue = "zendesk_import_status"

  def self.perform(args)
   Import::Zen::ZenStatusWorker.new(args).perform
  end 
end