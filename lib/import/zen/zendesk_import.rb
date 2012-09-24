class Import::Zen::ZendeskImport 
	extend Resque::Plugins::Retry
  @queue = 'zendeskImport'

  @retry_limit = 3
  @retry_delay = 60*2

  def self.perform(zen_params)
    Import::Zen::Start.new(zen_params).perform
  end
end