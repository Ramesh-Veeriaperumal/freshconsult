class Facebook::Worker::FacebookCommentsWorker
  extend Resque::AroundPerform
  include Facebook::KoalaWrapper::ExceptionHandler
  @queue = "facebook_comments_worker"


  def self.perform(args)
    account = Account.current

    raise_notification(account.id)
    
    Koala.config.api_version = nil #reset koala version so that we hit v1 api
    
    if args[:fb_page_id]
      fan_page = account.facebook_pages.find(args[:fb_page_id])
      fetch_fb_comments fan_page
    else
      facebook_pages = account.facebook_pages.valid_pages
      facebook_pages.each do |fan_page|
        fetch_fb_comments fan_page
      end
    end
  end

  def self.fetch_fb_comments fan_page
    sandbox(true) do
      @fan_page = fan_page
      fb_posts = Facebook::Graph::Posts.new(fan_page)
      fb_posts.get_comment_updates((Time.zone.now.ago 30.minutes).to_i)
    end
  end
  
  def self.raise_notification account_id
    message = {
      :account_id  => account_id,
      :environment => Rails.env
    }
    subject = "Realtime feature not enabled for: #{account_id}"
    topic = SNS["social_notification_topic"]
    DevNotification.publish(topic, subject, message.to_json)
  end

end
