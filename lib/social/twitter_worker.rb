class Social::TwitterWorker
	extend Resque::Plugins::Retry
  @queue = 'TwitterWorker'

  @retry_limit = 3
  @retry_delay = 60*2

  def self.perform(account_id)
    account = Account.find(account_id)
    account.make_current
    twitter_handles = account.twitter_handles.find(:all, :conditions => ["capture_dm_as_ticket = 1 or capture_mention_as_ticket = 1"])    
    twitter_handles.each do |twt_handle| 
      if twt_handle.capture_dm_as_ticket
        fetch_direct_msgs twt_handle
      end
      if twt_handle.capture_mention_as_ticket
        fetch_twt_mentions twt_handle
      end
    end
     Account.reset_current_account
  end

  def self.fetch_direct_msgs twt_handle
    sandbox do
      Timeout.timeout(60) do
        twt_msg = Social::TwitterMessage.new(twt_handle)
        twt_msg.process
      end
    end
  end

  def self.fetch_twt_mentions twt_handle
    sandbox do
      Timeout.timeout(60) do
        twt_mention = Social::TwitterMention.new(twt_handle)
        twt_mention.process
      end
    end
  end

  def self.sandbox(return_value = nil)
      begin
        return_value = yield
      rescue Timeout::Error
        puts "TIMEOUT - rescued - wait for 5 seconds and then proceed." 
        sleep(5) 
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        puts "Something wrong happened in twitter!"
        puts e.to_s
      rescue 
        puts "Something wrong happened in twitter!"
      end  
      return return_value   
  end
   

end