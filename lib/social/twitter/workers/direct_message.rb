class Social::Twitter::Workers::DirectMessage
  extend Resque::AroundPerform
  @queue = 'TwitterWorker'


  class Premium
    extend Resque::AroundPerform
    @queue = 'premium_twitter_worker'

    def self.perform(args)
      Social::Twitter::Workers::DirectMessage.run
    end
  end

  def self.perform(args)
    run
  end

  def self.run
    account = Account.current
    return if account.twitter_handles.empty?
    twitter_handles = account.twitter_handles.active
    twitter_handles.each do |twt_handle|
      @twt_handle = twt_handle
      fetch_direct_msgs twt_handle  if twt_handle.capture_dm_as_ticket
    end
  end

  def self.fetch_direct_msgs twt_handle
    sandbox do
      Timeout.timeout(60) do
        twt_msg = Social::Twitter::DirectMessage.new(twt_handle)
        twt_msg.process
      end
    end
  end

  def self.fetch_twt_mentions twt_handle
    sandbox do
      Timeout.timeout(60) do
        twt_mention = Social::Twitter::Mention.new(twt_handle)
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
      rescue Twitter::Error::TooManyRequests => e
        puts "Twitter API Rate Limit Error  -#{e.to_s} :: Account_id => #{@twt_handle.account_id}
                                  :: id => #{@twt_handle.id}"
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => @twt_handle.account_id,
                  :id => @twt_handle.id}})
      rescue Exception => e
        puts "Something wrong happened in twitter! Error-#{e.to_s} :: Account_id => #{@twt_handle.account_id}
                                  :: id => #{@twt_handle.id} "
        puts e.backtrace.join("\n")
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => @twt_handle.account_id,
                  :id => @twt_handle.id}})
      end
      return return_value
  end

   private

      def self.realtime_enabled?(account)
        account.subscription.trial?
      end

end
