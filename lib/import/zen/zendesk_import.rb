class Import::Zen::ZendeskImport 
  @queue = 'zendeskImport'

  def self.perform(zen_params)
    Import::Zen::Start.new(zen_params).perform
  end
end