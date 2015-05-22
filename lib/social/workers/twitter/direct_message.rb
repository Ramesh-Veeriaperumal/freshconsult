class Social::Workers::Twitter::DirectMessage
  extend Resque::AroundPerform
  
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
    begin
      twt_msg = Social::Twitter::DirectMessage.new(twt_handle)
      twt_msg.process
    rescue => e
      Rails.logger.error "Error while processing #{e.inspect}"
    end
  end
  
end
