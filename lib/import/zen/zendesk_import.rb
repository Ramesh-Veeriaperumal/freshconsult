require 'resque-retry'

class Import::Zen::ZendeskImport 
	extend Resque::Plugins::Retry
	
  @queue = 'zendeskImport'

  @retry_limit = 3
  
  def self.perform(zen_params)
  	trap("INT") do
     raise "Worker got Interrupted!"
     #either raise an error here if using a tool like resque-retry or requeue the job
    end
    trap('TERM') do
    	raise "Worker got Terminated!"
    end
    
    Import::Zen::Start.new(zen_params).perform
  end
end