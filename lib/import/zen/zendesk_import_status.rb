class Import::Zen::ZendeskImportStatus
  extend Resque::AroundPerform
  @queue = "ZendeskImportStatus"

  def self.perform(args)
   Import::Zen::ZenStatusWorker.new(args).perform
  end 
end