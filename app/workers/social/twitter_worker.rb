require 'twitter'
module Social
  class TwitterWorker < BaseWorker
    
    
    sidekiq_options :queue => :twitter, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(msg)
      account = Account.current
      twitter_handles = execute_on_db { account.twitter_handles.active }
      twitter_handles.each do |twt_handle|
        @twt_handle = twt_handle
        fetch_direct_msgs twt_handle  if twt_handle.capture_dm_as_ticket
      end
    end

    private

      def fetch_direct_msgs twt_handle
        sandbox do
          Timeout.timeout(60) do
            twt_msg = Social::Twitter::DirectMessage.new(twt_handle)
            twt_msg.process
          end
        end
      end

      def fetch_twt_mentions twt_handle
        sandbox do
          Timeout.timeout(60) do
            twt_mention = Social::Twitter::Mention.new(twt_handle)
            twt_mention.process
          end
        end
      end
      
      def sandbox(return_value = nil)
          begin
            return_value = yield
          rescue Timeout::Error
            logger.info "TIMEOUT - rescued - wait for 5 seconds and then proceed." 
            sleep(5) 
          rescue ::Twitter::Error::Unauthorized => e
            @twt_handle.state = Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]
            @twt_handle.last_error = e.to_s
            @twt_handle.save
            NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => @twt_handle.account_id,
                      :id => @twt_handle.id}})
            logger.info "Twitter Api Error -#{e.to_s} :: Account_id => #{@twt_handle.account_id}
                                      :: id => #{@twt_handle.id} "
          rescue ::Twitter::Error::TooManyRequests => e
            logger.info "Twitter API Rate Limit Error  -#{e.to_s} :: Account_id => #{@twt_handle.account_id}
                                      :: id => #{@twt_handle.id}"
            NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => @twt_handle.account_id,
                      :id => @twt_handle.id}})
          rescue Exception => e
            logger.info "Something wrong happened in twitter! Error-#{e.to_s} :: Account_id => #{@twt_handle.account_id}
                                      :: id => #{@twt_handle.id} "
            NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => @twt_handle.account_id,
                      :id => @twt_handle.id}})
          end  
          return return_value   
      end
  end
end