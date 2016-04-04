module Social
  class FacebookDelta 
      
    include Sidekiq::Worker
    include Social::Dynamo::UnprocessedFeed

    sidekiq_options :queue => :facebook_delta, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args)
      account = Account.current
      add_feeds_to_sqs(args['page_id'], args['discard_feed'])
    end

    #sort and push to sqs need to figure it out
    def add_feeds_to_sqs(page_id, discard_feed)
      fb_page = Account.current.facebook_pages.find_by_page_id(page_id)
      return unless fb_page
      
      while true 
        feeds = unprocessed_facebook_feeds(page_id)
        break if feeds.blank?
        sleep(10)
        fb_page.reload
        break unless fb_page.valid_page?
        Sqs::Message.new("{}").push(feeds, discard_feed)
      end
    rescue Exception => e
      SocialErrorsMailer.deliver_facebook_exception(e) unless Rails.env.test?
      Rails.logger.error "Cannot read data from dynamo db"
      NewRelic::Agent.notice_error(e,{:description => "Cannot read data from dynamo db"})
    end
      
  end
end

