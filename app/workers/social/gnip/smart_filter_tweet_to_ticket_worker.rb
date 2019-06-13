class Social::Gnip::SmartFilterTweetToTicketWorker < BaseWorker
  include Social::Twitter::Constants
  include Social::Util
  include Social::Gnip::Util

  sidekiq_options :queue => :smart_filter_tweet_to_ticket, :retry => 0, :failures => :exhausted

  def perform(args)
    args = args.deep_symbolize_keys
    unless args[:tweet].blank?
      gnip_msg = Social::Gnip::TwitterFeed.new(args[:tweet])
      begin
        gnip_msg.check_smart_filter(Account.current, args[:data])
      rescue Exception => e
        Rails.logger.debug "Exception in processing tweet using Smart filter"
        Rails.logger.debug "#{e.class} #{e.message} #{e.backtrace}"
        Rails.logger.debug args[:tweet].inspect
        NewRelic::Agent.notice_error(e, 
          { :custom_params => { :description => "JSON Parse error in gnip feed using Smart filter",
                                :tweet_obj => args[:tweet] }})
      end
    end
  end
end