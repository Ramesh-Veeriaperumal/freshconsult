require 'resque-retry'

class Import::Zen::ZendeskImport 
	extend Resque::Plugins::Retry
	
  @queue = 'zendeskImport'

  @retry_limit = 3
  @sleep_after_requeue = 60*5

  def self.perform(zen_params)
  	trap("INT") do
     raise "Worker got Interrupted!"
     #either raise an error here if using a tool like resque-retry or requeue the job
    end
    trap('TERM') do
    	raise "Worker got Terminated!"
    end
    trap('QUIT') do
    	raise "Worker getting QUIT!"
    end
    Import::Zen::Start.new(zen_params).perform
  end
end