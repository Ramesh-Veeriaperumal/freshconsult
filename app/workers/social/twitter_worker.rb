require 'twitter'
module Social
  class TwitterWorker < BaseWorker
    
    sidekiq_options :queue => :twitter, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args = nil)
      account = Account.current
      if args and args['twt_handle_id']
        twt_handle = account.twitter_handles.find(args['twt_handle_id'])
        fetch_direct_msgs twt_handle if twt_handle.capture_dm_as_ticket
      else
        return if account.twitter_handles.empty?
        twitter_handles = account.twitter_handles.active
        twitter_handles.each do |twt_handle|
          @twt_handle = twt_handle
          fetch_direct_msgs twt_handle  if twt_handle.capture_dm_as_ticket
        end
      end
    end

    private

      def fetch_direct_msgs twt_handle
        begin
          twt_msg = Social::Twitter::DirectMessage.new(twt_handle)
          twt_msg.process
        rescue => e
          Rails.logger.error "Error while processing: #{e.inspect}"
        end
      end
  end
end
