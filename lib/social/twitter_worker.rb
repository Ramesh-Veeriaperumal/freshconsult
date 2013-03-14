class Social::TwitterWorker
	extend Resque::AroundPerform
  @queue = 'TwitterWorker'


  def self.perform(args)
    account = Account.current
    twitter_handles = account.twitter_handles.active   
    twitter_handles.each do |twt_handle|
      @twt_handle = twt_handle 
      if twt_handle.capture_dm_as_ticket
        fetch_direct_msgs twt_handle
      end
      if twt_handle.capture_mention_as_ticket
        fetch_twt_mentions twt_handle
      end
    end
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
      rescue Twitter::Error::Unauthorized => e
        @twt_handle.state = Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]
        @twt_handle.last_error = e.to_s
        @twt_handle.save
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => @twt_handle.account_id,
                  :id => @twt_handle.id}})
        puts "Twitter Api Error -#{e.to_s} :: Account_id => #{@twt_handle.account_id}
                                  :: id => #{@twt_handle.id} "
      rescue Exception => e
        puts "Something wrong happened in twitter! Error-#{e.to_s} :: Account_id => #{@twt_handle.account_id}
                                  :: id => #{@twt_handle.id} "
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => @twt_handle.account_id,
                  :id => @twt_handle.id}})
      end  
      return return_value   
  end
   

end