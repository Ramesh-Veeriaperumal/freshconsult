class Social::Workers::Twitter::DirectMessage
  extend Resque::AroundPerform
  include Social::Twitter::ErrorHandler
  @queue = 'TwitterWorker'

  def self.perform(args)
    account = Account.current
    return if account.twitter_handles.empty?
    twitter_handles = account.twitter_handles.active
    twitter_handles.each do |twt_handle|
      @twt_handle = twt_handle
      fetch_direct_msgs twt_handle  if twt_handle.capture_dm_as_ticket
    end
  end

  def self.fetch_direct_msgs twt_handle
    twt_sandbox(twt_handle) do
      Timeout.timeout(60) do
        twt_msg = Social::Twitter::DirectMessage.new(twt_handle)
        twt_msg.process
      end
    end
  end

  # Possible dead code
  def self.fetch_twt_mentions twt_handle
    twt_sandbox(twt_handle) do
      Timeout.timeout(60) do
        twt_mention = Social::Twitter::Mention.new(twt_handle)
        twt_mention.process
      end
    end
  end

end
