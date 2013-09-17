class Import::Zen::ZendeskUserImport 
  extend Resque::AroundPerform

  @queue = "zendeskUserImport"

  def self.perform(args)
  	Import::Zen::UserImport.new(args[:user_xml])
  end
end